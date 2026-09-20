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

  def test_record_cast_emits_asciinema_events
    require "wezen"
    tui = Syrma::Session.new(backend: :tui, width: 20, height: 4) { |window| window.draw { Zaniah::Text.new("TUI") } }
    result = tui.record_cast(fps: 10, seed: 42) { |recording| recording.frame; recording.pause(0.2) }

    assert_equal ["resize", "output"], result.cast.events.map { |event| event.kind.to_s }.uniq
    assert_equal 200, result.duration_ms
    assert_equal 0.2, result.cast.events.last.time
    assert_operator Wezen::Cast.encode(width: result.cast.width, height: result.cast.height, events: result.cast.events).bytesize, :<, 100_000
  ensure
    tui&.close
  end

  def test_max_frames_is_enforced
    assert_raises(Syrma::Error) do
      @session.record(max_frames: 1) { |recording| recording.frame(count: 2) }
    end
  end

  def test_static_frames_share_one_buffer_and_accumulate_delay
    result = @session.record(fps: 10) { |recording| recording.frame(count: 3) }

    assert_equal 1, result.frames.length
    assert_equal 300, result.frames.first.delay_ms
  end

  def test_zoom_is_visible_while_its_duration_is_active
    plain = Syrma::Session.new(width: 80, height: 40, text: :none) { |window| CounterApp.mount(window) }
    zoomed = Syrma::Session.new(width: 80, height: 40, text: :none) { |window| CounterApp.mount(window) }
    plain_result = plain.record(fps: 10) { |recording| recording.frame }
    zoomed_result = zoomed.record(fps: 10) do |recording|
      recording.zoom(Zaniah::Bounds.new(40, 20, 20, 20), scale: 2, duration: 0.2)
    end

    refute_equal plain_result.frames.map(&:rgba), zoomed_result.frames.map(&:rgba)
  ensure
    plain&.close
    zoomed&.close
  end

  def test_chrome_does_not_change_the_application_tree
    before = @session.tree
    @session.record(fps: 10, seed: 42, chrome: {cursor: true, keycaps: true}) do |recording|
      recording.caption("demo")
      recording.frame
    end

    assert_equal before, @session.tree
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
