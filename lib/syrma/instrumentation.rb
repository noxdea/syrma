# frozen_string_literal: true

module Syrma
  module Instrumentation
    Capture = Struct.new(:backend, :windows, :on_open, keyword_init: true)

    module WindowCapture
      attr_reader :testing_root, :testing_clear, :testing_frame
      attr_accessor :testing_lazy_raster

      def on_frame(&callback)
        @testing_on_frame = callback
        super do |element, clear|
          @testing_root = element
          @testing_clear = clear
          @testing_frame = (@testing_frame || 0) + 1
          @testing_on_frame&.call(element, clear)
        end
      end

      def input(event)
        testing_recorder&.record(event)
        super
      end

      def testing_recorder = @testing_recorder

      def testing_recorder=(recorder)
        @testing_recorder = recorder
      end

      def render(element, present: true, **options)
        super(element, present: present && !testing_lazy_raster, **options)
      end
    end

    module BackendOverride
      def open_window(backend: :headless, **options)
        capture = Thread.current[:syrma_window_capture]
        return super unless capture

        window = if capture.backend
                   allowed = options.slice(:width, :height, :title, :scale_factor, :input, :output, :keymap, :clock)
                   super(backend: capture.backend, **allowed)
                 else
                   super
                 end
        capture.windows << window
        capture.on_open&.call(window)
        window
      end
    end

    class << self
      def install!
        return if @installed

        Zaniah::Platform.singleton_class.prepend(BackendOverride)
        @installed = true
      end

      def capture_windows(backend: :headless, on_open: nil)
        previous = Thread.current[:syrma_window_capture]
        capture = Capture.new(backend: backend, windows: [], on_open: on_open)
        Thread.current[:syrma_window_capture] = capture
        yield
        capture.windows
      ensure
        Thread.current[:syrma_window_capture] = previous
      end

      def capture(window, lazy_raster:)
        window.extend(WindowCapture) unless window.is_a?(WindowCapture)
        window.testing_lazy_raster = lazy_raster
        window.on_frame
        window
      end
    end
  end
end
