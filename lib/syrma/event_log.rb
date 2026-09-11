# frozen_string_literal: true

module Syrma
  Event = Data.define(:frame, :window, :input)

  class EventLog
    include Enumerable

    def initialize(limit: 100)
      @limit = limit
      @events = []
    end

    def each(&block) = @events.each(&block)
    def last(count = nil) = count ? @events.last(count) : @events.last

    def add(frame, window, input)
      @events.shift if @events.length >= @limit
      @events << Event.new(frame: frame, window: window, input: input)
    end
  end
end
