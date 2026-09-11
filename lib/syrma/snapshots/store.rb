# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"

module Syrma
  module Snapshots
    class Store
      NAME = /\A[A-Za-z0-9_-]+\z/

      attr_reader :root

      def initialize(root: nil, env: ENV)
        @root = File.expand_path(root || env["SYRMA_SNAPSHOT_DIR"] || Syrma.configuration.snapshot_dir)
        @env = env
      end

      def update? = @env["SYRMA_UPDATE_SNAPSHOTS"] == "1"
      def ci? = !@env["CI"].to_s.empty?

      def path(test_file:, test_class:, name:, ext:)
        unless name.to_s.match?(NAME)
          raise ArgumentError, "Snapshot names may contain only letters, digits, hyphens, and underscores: #{name.inspect}"
        end

        dir = File.join(root, File.basename(test_file.to_s, ".rb"), test_class.to_s.gsub(/[^A-Za-z0-9_-]/, "_"))
        File.join(dir, "#{name}.#{ext}").tap do |full|
          raise ArgumentError, "Snapshot path is outside the configured directory" unless full.start_with?(root + File::SEPARATOR)

          record(full)
        end
      end

      def write(path, bytes)
        FileUtils.mkdir_p(File.dirname(path))
        File.binwrite(path, bytes)
      end

      def usage_path
        File.join(ENV["SYRMA_ARTIFACTS"] || Syrma.configuration.artifacts_dir, "used-snapshots.txt")
      end

      def reset_usage!(full: false)
        FileUtils.mkdir_p(File.dirname(usage_path))
        File.write(usage_path, full ? "# full\n" : "# partial\n", encoding: "UTF-8")
      end

      def unused
        return [] unless File.exist?(usage_path)

        lines = File.readlines(usage_path, chomp: true, encoding: "UTF-8")
        raise Error, "Cannot prune snapshots after a partial test run" unless lines.first == "# full"

        used = lines.drop(1).to_h { |path| [File.expand_path(path), true] }
        Dir[File.join(root, "**", "*")].select { |path| File.file?(path) && !used[File.expand_path(path)] }
      end

      private

      def record(path)
        FileUtils.mkdir_p(File.dirname(usage_path))
        paths = [path]
        paths << path.sub(/\.png\z/, ".meta.json") if path.end_with?(".png")
        File.open(usage_path, "a", encoding: "UTF-8") { |file| paths.each { |used| file.puts(used) } }
      end
    end
  end

  module Visual
    module_function

    def meta(session)
      window = session.window
      text = window.text_system
      {
        zaniah: Zaniah::VERSION,
        size: [window.content_size.width, window.content_size.height],
        scale_factor: window.scale_factor,
        text: text&.class&.name,
        fonts: session.font_paths.map { |path| Digest::SHA256.file(path).hexdigest[0, 16] }
      }
    end

    def check_screenshot(session, store:, path:, threshold: 2, max_diff_pixels: 0,
                         max_diff_ratio: nil, region: nil, mask: [], artifacts: nil)
      validate_limits!(max_diff_pixels, max_diff_ratio)
      width = session.window.content_size.width.to_i
      height = session.window.content_size.height.to_i
      actual = session.screenshot_pixels.dup
      Array(mask).each { |target| Image.mask!(actual, width, height, bounds_for(target)) }
      width, height, actual = Image.crop(actual, width, height, bounds_for(region)) if region
      png = Zaniah::PNG.encode(width, height, actual)
      meta_path = path.sub(/\.png\z/, ".meta.json")

      unless File.exist?(path)
        if store.ci? && !store.update?
          raise SnapshotMissing, "Snapshot not found: #{path} (set SYRMA_UPDATE_SNAPSHOTS=1 to create it)"
        end
        write_golden(store, path, meta_path, png, session)
        return :created
      end

      expected_width, expected_height, expected = Zaniah::PNG.decode(File.binread(path))
      result = if [expected_width, expected_height] == [width, height]
                 Comparator.new(threshold: threshold).compare(width, height, expected, actual)
               end
      valid = result && result.diff_pixels <= max_diff_pixels &&
              (max_diff_ratio.nil? || result.ratio <= max_diff_ratio)
      return :matched if valid

      if store.update?
        write_golden(store, path, meta_path, png, session)
        return :updated
      end

      write_diff_artifacts(artifacts, path, png, width, height, result) if artifacts
      old_meta = File.exist?(meta_path) ? JSON.parse(File.read(meta_path, encoding: "UTF-8")) : {}
      font_hint = old_meta["fonts"] && old_meta["fonts"] != meta(session)[:fonts] ? "\n  Font configuration differs from the snapshot" : ""
      detail = if result
                 "#{result.diff_pixels} differing pixels (#{(result.ratio * 100).round(3)}%)"
               else
                 "size mismatch: expected #{expected_width}x#{expected_height}, got #{width}x#{height}"
               end
      raise SnapshotMismatch, "Image snapshot mismatch: #{File.basename(path)} #{detail}#{font_hint}" +
                              (artifacts ? "\n  Artifacts: #{artifacts}" : "")
    end

    def bounds_for(target)
      node = target.is_a?(Locator) ? target.resolve : target
      node.respond_to?(:bounds) ? node.bounds : node
    end

    def validate_limits!(pixels, ratio)
      raise ArgumentError, "max_diff_pixels must be a non-negative integer" unless pixels.is_a?(Integer) && pixels >= 0
      return if ratio.nil? || (ratio.is_a?(Numeric) && ratio.between?(0, 1))

      raise ArgumentError, "max_diff_ratio must be between 0.0 and 1.0"
    end

    def write_golden(store, path, meta_path, png, session)
      store.write(path, png)
      store.write(meta_path, JSON.pretty_generate(meta(session)))
    end

    def write_diff_artifacts(dir, expected_path, actual_png, width, height, result)
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "expected.png"), File.binread(expected_path))
      File.binwrite(File.join(dir, "actual.png"), actual_png)
      Zaniah::PNG.write(File.join(dir, "diff.png"), width, height, result.diff_image) if result
    end
  end
end
