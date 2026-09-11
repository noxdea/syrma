# frozen_string_literal: true

module Syrma
  module ScriptLauncher
    Launch = Struct.new(:fiber, :status, keyword_init: true)

    module WindowRun
      def run = Fiber.yield(self)
    end

    module AppRun
      def run
        return super unless Thread.current[:syrma_script_launch]

        Fiber.yield(self)
      end
    end

    module_function

    def launch(path, argv: [], backend: :headless, **options)
      install!
      Instrumentation.install!
      opened = []
      launch = Launch.new
      launch.fiber = Fiber.new do
        original_argv = ARGV.dup
        Thread.current[:syrma_script_launch] = true
        ARGV.replace(argv)
        Instrumentation.capture_windows(backend: backend, on_open: lambda { |window|
          opened << window
          window.extend(WindowRun)
        }) { load(File.expand_path(path)) }
        launch.status = 0
      rescue SystemExit => error
        launch.status = error.status
      ensure
        ARGV.replace(original_argv)
        Thread.current[:syrma_script_launch] = nil
      end
      launch.fiber.resume
      raise Error, "Script did not open a window: #{path}" if opened.empty?

      session = Session.new(**options, backend: backend, attached_windows: opened, owns_windows: true)
      session.launcher = launch
      session
    end

    def finish(launch)
      return unless launch&.fiber&.alive?

      launch.fiber.resume
    end

    def install!
      return if @installed

      Zaniah::App.prepend(AppRun)
      @installed = true
    end
  end
end
