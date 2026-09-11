# frozen_string_literal: true

require_relative "test_helper"

class DriverTest < Minitest::Test
  include Syrma::Minitest

  def setup
    keymap = Zaniah::Input::Keymap.new.bind("ctrl-s", :save)
    zaniah_session(width: 320, height: 240, keymap: keymap) { |window| CounterApp.mount(window) }
  end

  def test_click_by_id_text_and_hash
    ui.find(test_id: "inc").click
    ui.click(clickable: true, has_text: "-1")
    assert_ui_text "Count: 0"
  end

  def test_child_text_reaches_parent_handler
    ui.find(text: "+1").click
    assert_ui_text "Count: 1"
  end

  def test_strict_mode_reports_ambiguity
    error = assert_raises(Syrma::AmbiguousMatch) { ui.find(clickable: true).click }
    assert_match(/Matched 2 elements/, error.message)
    ui.find(clickable: true).last.click
    assert_ui_text "Count: -1"
  end

  def test_not_found_lists_visible_texts
    ui.instance_variable_set(:@timeout, 0.03)
    error = assert_raises(Syrma::WaitTimeout) { ui.find(test_id: "nope").click }
    assert_match(/Element not found.*Visible text/m, error.message)
  end

  def test_keymap_and_text_input
    ui.press("control-s")
    ui.type("héllo world")
    assert_ui_text "Saved: 1"
    assert_ui_text "Input: héllo world"
  end

  def test_tooltip_needs_virtual_time
    ui.test_id("inc").hover
    assert_nil ui.tooltip
    ui.advance(0.6)
    assert_tooltip "Increment"
  end

  def test_context_menu
    ui.test_id("inc").click
    ui.test_id("inc").right_click
    assert_menu_items ["Reset", "Disabled"]
    ui.press("enter")
    refute ui.menu.open?
    assert_ui_text "Count: 0"
  end

  def test_lazy_raster_pixels
    node = ui.test_id("inc").resolve
    x = (node.bounds.x + 5).to_i
    y = (node.bounds.y + 14).to_i
    assert_equal [0x33, 0x44, 0x55, 255], ui.pixel(x, y)
    assert_pixel x, y, "#345"
  end
end

class OverlayTest < Minitest::Test
  include Syrma::Minitest

  def test_obscured_element_is_reported
    zaniah_session(width: 320, height: 240, timeout: 0.03) { |window| CounterApp.mount(window, overlay: true) }
    error = assert_raises(Syrma::WaitTimeout) { ui.test_id("inc").click }
    assert_match(/is covered by .*overlay/, error.message)
    ui.click(ui.test_id("inc"), force: true)
    assert_ui_text "Count: 0"
  end
end

class AsyncTest < Minitest::Test
  include Syrma::Minitest

  def test_background_task_result_is_awaited
    app = Zaniah::App.new
    zaniah_session(width: 200, height: 80, app: app) do |window|
      app.windows << window
      AsyncApp.mount(app, window)
    end
    ui.find(text: /State/).click
    assert_ui_text "State: done"
  ensure
    app.executor.shutdown
  end

  def test_shared_virtual_clock_drives_executor_timeout
    clock = Syrma::Clock.new
    app = Zaniah::App.new(clock: clock)
    pending = Zaniah::Task.new
    timed = app.executor.spawn { pending.await(timeout: 1) }
    zaniah_session(width: 100, height: 50, app: app, clock: clock) { |window| window.draw { Zaniah::Div.new } }
    ui.advance(1)
    assert_raises(Zaniah::Task::Timeout) { timed.await }
  ensure
    app&.executor&.shutdown
  end
end
