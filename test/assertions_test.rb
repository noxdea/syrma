# frozen_string_literal: true

require_relative "test_helper"

class AssertionsTest < Minitest::Test
  include Syrma::Minitest

  def setup
    zaniah_session(width: 320, height: 240, text: :none, timeout: 0.01) { |window| CounterApp.mount(window) }
  end

  def test_visibility_clickability_and_background
    assert_visible(test_id: "inc")
    assert_hidden(test_id: "missing")
    assert_clickable(test_id: "inc")
    assert_bg ui.test_id("inc"), "#345"
    assert_raises(Minitest::Assertion) { assert_bg ui.test_id("inc"), "#fff" }
  end

  def test_pixel_and_menu_failures_are_assertions
    node = ui.test_id("inc").resolve
    x = (node.bounds.x + 5).to_i
    y = (node.bounds.y + 14).to_i
    assert_pixel x, y, "#345"
    assert_raises(Minitest::Assertion) { assert_pixel x, y, "#fff" }
    assert_raises(Minitest::Assertion) { assert_menu_items ["missing"] }
  end

  def test_panel_and_decoration_assertions_use_rendered_instrumentation
    session = zaniah_session(width: 320, height: 240, text: :none, timeout: 0.01) do |window|
      InstrumentedUIApp.mount(window)
    end

    assert_panel_visible :problems, session: session
    assert_panel_badge :problems, 3, session: session
    assert_inline_overlay line: 10, text: ": String", session: session
    assert_gutter_marker line: 5, kind: :breakpoint, session: session
    assert_line_highlight line: 12, kind: :debug_position, session: session
  end

  def test_new_assertion_failures_report_available_instrumentation
    session = zaniah_session(width: 320, height: 240, text: :none, timeout: 0.001) do |window|
      InstrumentedUIApp.mount(window)
    end

    error = assert_raises(Minitest::Assertion) { assert_panel_badge :problems, 4, session: session }
    assert_match(/syrma:panel:problems:badge="3" \(visible\)/, error.message)
    error = assert_raises(Minitest::Assertion) do
      assert_gutter_marker line: 6, kind: :breakpoint, session: session
    end
    assert_match(/syrma:decoration:gutter:5:breakpoint/, error.message)
    assert_raises(ArgumentError) { assert_inline_overlay line: -1, text: "invalid", session: session }
  end
end
