# frozen_string_literal: true

module Syrma
  class Configuration
    attr_accessor :timeout, :strict, :event_frames, :text, :fonts, :snapshot_dir, :artifacts_dir

    def initialize
      @timeout = 2.0
      @strict = true
      @event_frames = :each
      @text = :deterministic
      @fonts = []
      @snapshot_dir = "test/syrma_snapshots"
      @artifacts_dir = "tmp/syrma"
    end
  end
end
