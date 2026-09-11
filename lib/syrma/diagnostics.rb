# frozen_string_literal: true

require "fileutils"

module Syrma
  module Diagnostics
    module_function

    def dir_for(test_class, test_name)
      root = ENV["SYRMA_ARTIFACTS"] || Syrma.configuration.artifacts_dir
      File.join(root, sanitize(test_class), sanitize(test_name))
    end

    def write(session, dir, message: nil)
      FileUtils.mkdir_p(dir)
      tree = session.tree
      size = session.window.content_size
      Zaniah::PNG.write(File.join(dir, "screenshot.png"), size.width.to_i, size.height.to_i, session.screenshot_pixels)
      File.write(File.join(dir, "tree.txt"), tree.root ? TreeFormat.dump(tree.root) : "(nothing rendered)\n", encoding: "UTF-8")
      File.write(File.join(dir, "hits.txt"), hits(tree), encoding: "UTF-8")
      File.write(File.join(dir, "text_runs.txt"), text_runs(tree), encoding: "UTF-8")
      File.write(File.join(dir, "events.log"), events(session), encoding: "UTF-8")
      File.write(File.join(dir, "terminal.txt"), session.terminal_lines.join("\n") + "\n", encoding: "UTF-8") if session.tui?
      File.write(File.join(dir, "summary.md"), summary(session, dir, message, tree, size), encoding: "UTF-8")
      dir
    rescue StandardError => error
      warn "syrma: failed to write diagnostics: #{error.class}: #{error.message}"
      nil
    end

    def sanitize(value) = value.to_s.gsub(/[^A-Za-z0-9_-]/, "_")

    def hits(tree)
      tree.hits.each_with_index.map do |(bounds, node), index|
        "#{index}: [#{bounds.x},#{bounds.y} #{bounds.width}x#{bounds.height}] #{node ? node.inspect : '(unknown)'}"
      end.join("\n") + "\n"
    end

    def text_runs(tree)
      tree.text_runs.map { |x, y, text, color| "#{x},#{y} #{color} #{text.inspect}" }.join("\n") + "\n"
    end

    def events(session)
      session.event_log.last(100).map do |event|
        "frame=#{event.frame} window=#{event.window.inspect} #{event.input.inspect}"
      end.join("\n") + "\n"
    end

    def summary(_session, dir, message, tree, size)
      links = %w[screenshot.png tree.txt hits.txt text_runs.txt events.log terminal.txt expected.png actual.png diff.png]
        .select { |name| File.exist?(File.join(dir, name)) }
        .map { |name| "[#{name}](#{name})" }.join(" / ")
      <<~MARKDOWN
        # #{File.basename(dir)}

        #{message}

        - zaniah #{Zaniah::VERSION} / Ruby #{RUBY_VERSION} / #{RUBY_PLATFORM}
        - window #{size.width}x#{size.height}, frame #{tree.frame}
        - #{links}
      MARKDOWN
    end
  end
end
