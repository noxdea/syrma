# frozen_string_literal: true

module Syrma
  class Recorder
    def initialize(driver, output)
      @driver = driver
      @output = output
      @started_at = Clock.real_now
      driver.window.testing_recorder = self
    end

    def record(event)
      target = target_for(event)
      @output.puts(EventCodec.dump(event, t: Clock.real_now - @started_at, target: target))
      @output.flush if @output.respond_to?(:flush)
    end

    def close
      @driver.window.testing_recorder = nil if @driver.window.testing_recorder.equal?(self)
    end

    private

    def target_for(event)
      return unless event.is_a?(Zaniah::Input::MouseDown)

      node = @driver.at(event.position, event: :mouse_down, button: event.button)
      return unless node

      {"test_id" => node.test_id, "text" => node.content_text}.compact
    rescue Error
      nil
    end
  end
end
