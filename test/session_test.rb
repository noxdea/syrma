# frozen_string_literal: true

require_relative "test_helper"

class SessionTest < Minitest::Test
  def test_attach_does_not_take_window_ownership
    window = Zaniah::Platform.open_window(width: 100, height: 50)
    window.draw { Zaniah::Text.new("Attached") }
    session = Syrma::Session.attach(window, text: :none)
    assert_includes session.texts, "Attached"
    session.close
    refute window.closed?
  ensure
    window&.close
  end

  def test_for_app_tracks_windows_opened_later
    app = Zaniah::App.new
    session = Syrma::Session.for_app(app, text: :none) { |current| MultiWindowApp.open_windows(current) }
    assert_equal "Main", session.window.title
    session.test_id("settings").click
    session.window(title: "Settings")
    assert_includes session.texts, "Settings ready"
    assert_equal 2, session.windows.length
    session.close
    assert session.windows.all?(&:closed?)
  ensure
    app&.executor&.shutdown
  end

  def test_animation_is_reported_as_unstable
    assert_raises(Syrma::UnstableUI) do
      Syrma::Session.new(width: 100, height: 50, text: :none, max_frames: 2) { |window| AnimationApp.mount(window) }
    end
  end

  def test_custom_element_is_instrumented
    clicked = nil
    session = Syrma::Session.new(width: 100, height: 50, text: :none) { |window| clicked = CustomElementApp.mount(window) }
    session.test_id("custom").click
    assert_equal [true], clicked
  ensure
    session&.close
  end

  def test_application_on_frame_callback_is_preserved
    frames = []
    session = Syrma::Session.new(width: 100, height: 50, text: :none) do |window|
      window.on_frame { |element, clear| frames << [element, clear] }
      window.draw { Zaniah::Div.new }
    end
    assert_equal 1, frames.length
    assert_same session.window.testing_root, frames.first.first
    assert_equal Zaniah::Platform::Headless::Window::DEFAULT_CLEAR, frames.first.last
  ensure
    session&.close
  end
end
