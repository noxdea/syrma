# frozen_string_literal: true

require_relative "test_helper"

class RecordingTest < Minitest::Test
  def setup
    @session = Syrma::Session.new(width: 80, height: 40, text: :none) { |window| CounterApp.mount(window) }
  end

  def teardown
    @session&.close
  end

  def test_recording_uses_virtual_time_and_is_repeatable
    first = run_script
    second = run_script
    assert_equal first.frames.map(&:rgba), second.frames.map(&:rgba)
    assert_equal first.frames.map(&:delay_ms), second.frames.map(&:delay_ms)
    assert_equal first.duration_ms, second.duration_ms
  end

  def test_record_rejects_real_clock
    real = Syrma::Session.new(width: 20, height: 20, text: :none, clock: :real) { |window| window.draw { Zaniah::Div.new } }
    assert_raises(Syrma::Error) { real.record { |recording| recording.frame } }
  ensure
    real&.close
  end

  def test_record_rejects_tui_backend
    tui = Syrma::Session.new(backend: :tui, width: 20, height: 20) { |window| window.draw { Zaniah::Text.new("TUI") } }
    assert_raises(Syrma::Error) { tui.record { |recording| recording.frame } }
  ensure
    tui&.close
  end

  def test_max_frames_is_enforced
    assert_raises(Syrma::Error) do
      @session.record(max_frames: 1) { |recording| recording.frame(count: 2) }
    end
  end

  private

  def run_script
    @session.record(fps: 10, seed: 42) do |recording|
      recording.frame
      recording.type_humanly("hello", cps: 12)
      recording.pause(0.2)
    end
  end
end
