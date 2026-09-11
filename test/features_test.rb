# frozen_string_literal: true

require_relative "test_helper"

class TodoToolTest < Minitest::Test
  include Syrma::Minitest

  def setup
    zaniah_session(width: 480, height: 320) { |window| TodoTool.mount(window) }
  end

  def test_add_and_delete
    ui.type("Buy milk")
    ui.press("enter")
    assert_element ui.find(test_id: "item-0", has_text: "Buy milk")
    ui.find(test_id: "item-0").find(tooltip: "Delete").hover
    ui.advance(0.6)
    assert_tooltip "Delete"
    ui.find(test_id: "item-0").find(clickable: true).click
    refute_element(test_id: "item-0")
  end
end

class ShortcutTest < Minitest::Test
  include Syrma::Minitest

  def test_button_bg_and_at
    zaniah_session(width: 320, height: 240, text: :none) { |window| CounterApp.mount(window) }
    ui.button("+1").click
    assert_ui_text "Count: 1"
    assert_bg ui.test_id("inc"), "#334455"
    assert_equal "inc", ui.at(ui.test_id("inc").resolve.center).test_id
  end

  def test_key_sequence_timeout_with_virtual_clock
    keymap = Zaniah::Input::Keymap.new.bind("ctrl-k ctrl-s", :save)
    zaniah_session(width: 320, height: 240, keymap: keymap) { |window| CounterApp.mount(window) }
    ui.press("ctrl-k", "ctrl-s")
    assert_ui_text "Saved: 1"
    ui.press("ctrl-k")
    ui.advance(1.1)
    ui.press("ctrl-s")
    assert_ui_text "Saved: 1"
  end

  def test_tui_session_keeps_terminal_renderer
    zaniah_session(backend: :tui, width: 160, height: 60) do |window|
      window.draw { Zaniah::Text.new("Hello TUI").test_id("t") }
    end
    assert_kind_of Zaniah::Platform::TUI::TextRenderer, ui.window.text_system
    assert_includes ui.terminal_lines, "Hello TUI"
    ui.feed_terminal("a")
  end

  def test_unknown_criteria_is_rejected
    zaniah_session(width: 100, height: 100, text: :none) { |window| window.draw { Zaniah::Div.new } }
    assert_raises(ArgumentError) { ui.find(txt: "typo") }
  end

  def test_configuration_and_environment_precedence
    original = Syrma.configuration
    Syrma.configuration = Syrma::Configuration.new
    Syrma.configure do |config|
      config.timeout = 4.0
      config.strict = false
      config.event_frames = :gesture
      config.text = :none
    end
    ENV["SYRMA_TIMEOUT"] = "3.0"
    ENV["SYRMA_RASTER"] = "eager"
    configured = zaniah_session(width: 10, height: 10) { |window| window.draw { Zaniah::Div.new } }
    assert_equal 3.0, configured.timeout
    assert_equal :gesture, configured.event_frames
    assert_equal :none, configured.text_mode
    assert_equal :eager, configured.raster
    explicit = zaniah_session(width: 10, height: 10, timeout: 1.0, raster: :lazy) { |window| window.draw { Zaniah::Div.new } }
    assert_equal 1.0, explicit.timeout
    assert_equal :lazy, explicit.raster
    refute configured.strict
  ensure
    ENV.delete("SYRMA_TIMEOUT")
    ENV.delete("SYRMA_RASTER")
    Syrma.configuration = original
  end
end

class ClockTest < Minitest::Test
  def test_virtual_clock_advances_without_changing_process_time
    clock = Syrma::Clock.new
    virtual = clock.call
    process = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    clock.advance(2)
    assert_equal virtual + 2, clock.call
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - process, :<, 0.1
    assert_raises(ArgumentError) { clock.advance(-1) }
  end
end
