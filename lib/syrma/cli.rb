# frozen_string_literal: true

require "fileutils"
require "optparse"
require_relative "../syrma"

module Syrma
  class CLI
    def self.run(argv = ARGV, out: $stdout, err: $stderr)
      new(out: out, err: err).run(argv.dup)
    end

    def initialize(out:, err:)
      @out = out
      @err = err
    end

    def run(arguments)
      command = arguments.shift
      case command
      when "doctor" then doctor
      when "snapshots" then snapshots(arguments)
      when "report" then report(arguments)
      when "record" then record(arguments)
      when "codegen" then codegen(arguments)
      when nil, "help", "--help", "-h" then help
      else
        @err.puts "Unknown command: #{command}"
        help(@err)
        1
      end
    rescue OptionParser::ParseError, ArgumentError, Error => error
      @err.puts error.message
      1
    end

    private

    def doctor
      checks = {
        "Ruby" => "#{RUBY_VERSION} (#{RUBY_PLATFORM})",
        "zaniah" => Zaniah::VERSION,
        "Bundled font" => File.file?(Internals.bundled_font_path) ? Internals.bundled_font_path : nil,
        "YJIT" => defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "enabled" : "disabled",
        "External encoding" => Encoding.default_external.name
      }
      checks.each { |name, value| @out.puts format("%-14s %s", name, value || "NG") }
      checks.values.all? ? 0 : 1
    end

    def snapshots(arguments)
      subcommand = arguments.shift
      case subcommand
      when "update" then update_snapshots(arguments)
      when "prune" then prune_snapshots(arguments)
      else raise ArgumentError, "Usage: syrma snapshots update [test files] | prune [--dry-run]"
      end
    end

    def update_snapshots(files)
      Snapshots::Store.new.reset_usage!(full: files.empty?)
      env = {"SYRMA_UPDATE_SNAPSHOTS" => "1"}
      command = ["bundle", "exec", "rake", "test"]
      command << "TEST=#{files.join(' ')}" unless files.empty?
      system(env, *command) ? 0 : 1
    end

    def prune_snapshots(arguments)
      dry_run = arguments.delete("--dry-run")
      raise ArgumentError, "Unknown arguments: #{arguments.join(' ')}" unless arguments.empty?

      files = Snapshots::Store.new.unused
      files.each { |path| @out.puts(dry_run ? "would remove #{path}" : "removed #{path}") }
      files.each { |path| FileUtils.rm_f(path) } unless dry_run
      0
    end

    def report(arguments)
      open_report = arguments.delete("--open")
      raise ArgumentError, "Unknown arguments: #{arguments.join(' ')}" unless arguments.empty?

      path = Report.generate
      @out.puts path
      open_path(path) if open_report
      0
    end

    def record(arguments)
      output = "recording.jsonl"
      parser = OptionParser.new { |options| options.on("--out PATH") { |path| output = path } }
      parser.parse!(arguments)
      script = arguments.shift or raise ArgumentError, "Usage: syrma record SCRIPT [--out PATH]"
      raise ArgumentError, "Unknown arguments: #{arguments.join(' ')}" unless arguments.empty?

      sessions = []
      recorders = []
      File.open(output, "w", encoding: "UTF-8") do |file|
        Instrumentation.install!
        Instrumentation.capture_windows(backend: nil, on_open: lambda { |window|
          session = Session.attach(window, text: :native, raster: :eager)
          sessions << session
          recorders << Recorder.new(session.driver, file)
        }) { load(File.expand_path(script)) }
      end
      @out.puts output
      0
    ensure
      recorders&.each(&:close)
      sessions&.each(&:close)
    end

    def codegen(arguments)
      framework = :minitest
      parser = OptionParser.new { |options| options.on("--framework NAME") { |name| framework = name.to_sym } }
      parser.parse!(arguments)
      raise ArgumentError, "framework must be minitest or rspec" unless %i[minitest rspec].include?(framework)

      path = arguments.shift or raise ArgumentError, "Usage: syrma codegen RECORDING [--framework minitest|rspec]"
      raise ArgumentError, "Unknown arguments: #{arguments.join(' ')}" unless arguments.empty?

      @out.write(Codegen.generate(File.readlines(path, encoding: "UTF-8"), framework: framework))
      0
    end

    def open_path(path)
      command = if RUBY_PLATFORM.include?("darwin")
                  ["open", path]
                elsif RUBY_PLATFORM.match?(/mswin|mingw/)
                  ["cmd", "/c", "start", "", path]
                else
                  ["xdg-open", path]
                end
      system(*command)
    end

    def help(io = @out)
      io.puts <<~HELP
        Usage: syrma COMMAND
          doctor
          snapshots update [test files]
          snapshots prune [--dry-run]
          report [--open]
          record SCRIPT [--out recording.jsonl]
          codegen RECORDING [--framework minitest|rspec]
      HELP
      0
    end
  end
end
