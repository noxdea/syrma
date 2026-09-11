# frozen_string_literal: true

module Syrma
  class Clock
    def self.real_now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def initialize = @now = self.class.real_now
    def call = @now

    def advance(seconds)
      raise ArgumentError, "time cannot be negative" unless seconds.is_a?(Numeric) && seconds >= 0

      @now += seconds.to_f
    end
  end

  class VirtualKeymap
    def initialize(keymap, clock) = (@keymap, @clock = keymap, clock)

    def dispatch(key, context: {})
      @keymap.dispatch(key, context: context, now: @clock.call)
    end
  end
end
