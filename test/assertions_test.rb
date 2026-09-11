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
end
