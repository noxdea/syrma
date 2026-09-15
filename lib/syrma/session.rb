# frozen_string_literal: true

require "stringio"

module Syrma
  class Session
    attr_reader :raster, :strict, :timeout, :event_log, :app, :event_frames, :font_paths, :text_mode, :windows, :drivers

    class << self
      def attach(window, **options) = new(**options, attached_windows: [window], owns_windows: false)
      def launch_script(path, argv: [], **options) = ScriptLauncher.launch(path, argv: argv, **options)

      def for_app(app, backend: :headless, **options)
        Instrumentation.install!
        windows = Instrumentation.capture_windows(backend: backend) { yield(app) }
        raise Error, "No window was opened inside the block" if windows.empty?

        new(**options, backend: backend, app: app, attached_windows: windows, owns_windows: true)
      end
    end

    def initialize(width: 800, height: 600, backend: :headless, text: nil, fonts: nil,
                   raster: nil, clock: :virtual, strict: nil, timeout: nil, keymap: nil,
                   app: nil, max_frames: 20, event_frames: nil, attached_windows: nil,
                   owns_windows: true, **window_options, &mount)
      config = Syrma.configuration
      text ||= config.text
      fonts ||= config.fonts
      strict = config.strict if strict.nil?
      timeout ||= ENV["SYRMA_TIMEOUT"] || config.timeout
      event_frames ||= config.event_frames
      raster ||= ENV["SYRMA_RASTER"] == "eager" ? :eager : :lazy
      validate_options!(backend, event_frames, raster, clock)
      Instrumentation.install!

      @raster = raster
      @strict = strict
      @app = app
      @max_frames = max_frames
      @clock = clock == :virtual ? Clock.new : (clock == :real ? Zaniah::MONOTONIC_CLOCK : clock)
      @event_frames = event_frames
      @timeout = Float(timeout)
      @event_log = EventLog.new
      @text_mode = text
      @owns_windows = owns_windows
      @backend = backend
      @text = text
      @fonts = fonts
      keymap = VirtualKeymap.new(keymap, @clock) if keymap
      @outputs = {}
      @windows = attached_windows || [open_window(backend, width, height, window_options, keymap)]
      @drivers = @windows.map { |window| prepare(window, backend, text, fonts) }
      @font_paths = text == :deterministic ? [Internals.bundled_font_path, *fonts.map { |font| File.expand_path(font) }] : []
      @current = 0
      mount&.call(window)
      settle
    end

    def window(title: nil, index: nil)
      return @windows[@current] unless title || index

      selected = index ? @windows[index] : @windows.find { |candidate| candidate.title == title }
      raise Error, "Window not found: #{title ? "title: #{title.inspect}" : "index: #{index}"}" unless selected

      @current = @windows.index(selected)
      driver
    end

    def driver = @drivers[@current]
    def session = self
    def virtual_clock? = @clock.is_a?(Clock)
    def method_missing(name, ...) = driver.respond_to?(name) ? driver.public_send(name, ...) : super
    def respond_to_missing?(name, include_all = false) = driver.respond_to?(name, include_all) || super

    def settle
      @max_frames.times do
        @app&.executor&.drain
        sync_app_windows
        busy = false
        @windows.each do |candidate|
          next if candidate.closed? || !candidate.dirty?

          candidate.tick
          busy = true
        end
        return self unless busy || (@app && !Internals.executor_idle?(@app.executor))
      end
      raise UnstableUI, "UI did not stabilize within #{@max_frames} frames (continuous animation?)"
    end

    def advance(seconds)
      raise Error, "advance is unavailable for this clock" unless @clock.respond_to?(:advance)

      @clock.advance(seconds)
      @windows.reject(&:closed?).each(&:tick)
      settle
    end

    def wait_for(message = "Condition was not met", timeout: @timeout)
      deadline = Clock.real_now + timeout
      loop do
        settle
        result = yield
        return result if result

        if Clock.real_now >= deadline
          detail = message.respond_to?(:call) ? message.call : message
          raise WaitTimeout, "Timed out after #{timeout} seconds: #{detail}"
        end
        sleep 0.01
      end
    end

    def screenshot_pixels(target = driver)
      settle
      clear = target.window.testing_clear || Zaniah::Platform::Headless::Window::DEFAULT_CLEAR
      target.window.device.render(target.window.scene, clear: clear)
    end

    def tui?(target = driver) = @outputs.key?(target.window)
    def output_for(target = driver) = @outputs.fetch(target.window)
    def exit_status = @launcher&.status

    def launcher=(launcher)
      @launcher = launcher
    end

    def close
      closed = !@owns_windows || @windows.map { |candidate| candidate.closed? || candidate.close }.all?
      ScriptLauncher.finish(@launcher) if @launcher
      closed
    end

    private

    def validate_options!(backend, event_frames, raster, clock)
      raise ArgumentError, "backend must be :headless or :tui" unless %i[headless tui].include?(backend)
      raise ArgumentError, "event_frames must be :each or :gesture" unless %i[each gesture].include?(event_frames)
      raise ArgumentError, "raster must be :lazy or :eager" unless %i[lazy eager].include?(raster)
      raise ArgumentError, "clock must be :virtual, :real, or callable" unless %i[virtual real].include?(clock) || clock.respond_to?(:call)
    end

    def open_window(backend, width, height, options, keymap)
      options = options.merge(clock: @clock)
      options[:keymap] = keymap if keymap
      if backend == :tui
        output = options[:output] || StringIO.new
        window = Zaniah::Platform.open_window(backend: backend, width: width, height: height,
                                              input: options[:input] || StringIO.new, output: output,
                                              **options.except(:input, :output))
        @outputs[window] = output
        window
      else
        Zaniah::Platform.open_window(backend: backend, width: width, height: height, **options)
      end
    end

    def prepare(candidate, backend, text, fonts)
      actual_backend = candidate.is_a?(Zaniah::Platform::TUI::Window) ? :tui : backend
      candidate.text_system = TextSystems.build(text, fonts: fonts) unless actual_backend == :tui
      WindowDriver.new(candidate, self)
    end

    def sync_app_windows
      return unless @app

      (@app.windows - @windows).each do |candidate|
        @windows << candidate
        @drivers << prepare(candidate, @backend, @text, @fonts)
      end
    end
  end
end
