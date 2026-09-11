# frozen_string_literal: true

require_relative "test_helper"

class InteractionTest < Minitest::Test
  include Syrma::Minitest

  def setup
    @state = nil
    zaniah_session(width: 400, height: 200, text: :none) { |window| @state = WidgetsApp.mount(window) }
  end

  def test_drag_is_captured_until_mouse_up
    ui.drag(ui.test_id("knob"), Zaniah::Point.new(390, 190), steps: 4)
    assert_ui_text "x=390"
  end

  def test_scroll_and_scroll_until
    refute ui.test_id("row-50").exists?
    ui.scroll_until(ui.test_id("list"), found: {test_id: "row-50"})
    assert ui.test_id("row-50").visible?
    ui.scroll(ui.test_id("list"), dy: -100_000)
    assert ui.test_id("row-0").visible?
  end

  def test_ime_paste_and_file_drop
    ui.compose("hel")
    assert_ui_text "ime=hel|"
    ui.commit("hello")
    ui.paste(" world")
    assert_ui_text "ime=|hello world"
    ui.drop_files(["/tmp/a.txt", "/tmp/b.txt"], at: ui.test_id("knob"))
    assert_ui_text "dropped=/tmp/a.txt,/tmp/b.txt"
  end

  def test_resize
    ui.resize(300, 150)
    assert_equal [300, 150], @state[:resized]
    assert_equal 300, ui.tree.size.width
  end

  def test_menu_keyboard_and_mouse
    ui.test_id("knob").right_click
    assert_equal "Copy", ui.menu.selected
    assert_raises(Syrma::NotActionable) { ui.menu.select("Disabled") }
    ui.menu.select("Paste")
    ui.test_id("knob").right_click
    ui.menu.select("Copy", via: :mouse)
    assert_equal %i[paste copy], @state[:picked]
  end

  def test_menu_blocks_other_clicks
    ui.test_id("knob").right_click
    ui.instance_variable_set(:@timeout, 0.03)
    error = assert_raises(Syrma::WaitTimeout) { ui.test_id("knob").click }
    assert_match(/context menu/, error.message)
    ui.menu.dismiss
  end

  def test_low_level_input
    point = ui.test_id("knob").resolve.center
    ui.mouse_move(point)
    ui.mouse_down(point)
    ui.mouse_up(point)
    ui.key_down("a", held: true)
    ui.key_up("a")
    assert_operator ui.event_log.to_a.length, :>=, 5
  end

  def test_close_rejection_and_backend_guard
    ui.window.on_close { false }
    refute ui.close
    refute ui.window.closed?
    assert_raises(Syrma::UnsupportedBackend) { ui.feed_terminal("x") }
    ui.window.on_close { true }
  end

  def test_tree_format
    assert_equal "div @knob [158,8 20x20] bg=#48c on=drag\n", Syrma::TreeFormat.dump(ui.test_id("knob").resolve)
  end
end

class TerminalTest < Minitest::Test
  include Syrma::Minitest

  def test_terminal_lines_and_overlap_detection
    zaniah_session(backend: :tui, width: 160, height: 60) do |window|
      window.draw { Zaniah::Div.new.flex_col.child(Zaniah::Text.new("Hello")).child(Zaniah::Text.new("World")) }
    end
    assert_equal %w[Hello World], ui.terminal_lines.first(2)
    assert_no_text_overlap
  end

  def test_no_overlap_when_rows_are_aligned
    zaniah_session(backend: :tui, width: 160, height: 60) do |window|
      window.draw do
        Zaniah::Div.new.flex_col.child(Zaniah::Text.new("Hello").h(20)).child(Zaniah::Text.new("World").h(20))
      end
    end
    assert_equal %w[Hello World], ui.terminal_lines.first(2)
    assert_no_text_overlap
  end
end
