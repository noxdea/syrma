# frozen_string_literal: true

require "syrma/rspec"
require "tmpdir"
require_relative "../test/fixtures/apps/counter_app"
require_relative "../test/fixtures/apps/instrumented_ui_app"

RSpec.describe "Syrma counter matchers", type: :zaniah do
  around do |example|
    old = ENV["SYRMA_SNAPSHOT_DIR"]
    Dir.mktmpdir("syrma-rspec") do |dir|
      ENV["SYRMA_SNAPSHOT_DIR"] = dir
      example.run
    end
  ensure
    old ? ENV["SYRMA_SNAPSHOT_DIR"] = old : ENV.delete("SYRMA_SNAPSHOT_DIR")
  end

  before { zaniah_session(width: 320, height: 240) { |window| CounterApp.mount(window) } }

  it "matches text, elements, visibility, actionability, color, and pixels" do
    ui.test_id("inc").click
    expect(ui).to have_ui_text("Count: 1")
    expect(ui).not_to have_ui_text("Count: 0")
    expect(ui).to have_element(test_id: "label")
    expect(ui.test_id("inc")).to be_visible
    expect(ui.test_id("inc")).to be_clickable
    expect(ui.test_id("inc")).to have_bg("#345")
    node = ui.test_id("inc").resolve
    expect(ui).to have_pixel((node.bounds.x + 5).to_i, (node.bounds.y + 14).to_i, "#345")
  end

  it "matches popups and snapshots" do
    ui.test_id("inc").hover
    ui.advance(0.6)
    expect(ui).to have_tooltip("Increment")
    ui.test_id("inc").right_click
    expect(ui).to have_menu_items(["Reset", "Disabled"])
    ui.menu.dismiss
    expect(ui).to match_tree_snapshot("counter")
    expect(ui).to match_screenshot("counter")
  end

  it "reports why an obscured element is not clickable" do
    second = zaniah_session(width: 320, height: 240, timeout: 0.03) { |window| CounterApp.mount(window, overlay: true) }
    expect { expect(second.test_id("inc")).to be_clickable }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /is covered by .*overlay/)
  end
end

RSpec.describe "Syrma UI instrumentation matchers", type: :zaniah do
  before do
    zaniah_session(width: 320, height: 240, text: :none, timeout: 0.01) do |window|
      InstrumentedUIApp.mount(window)
    end
  end

  it "matches panels and decorations" do
    expect(ui).to have_panel_visible(:problems)
    expect(ui).to have_panel_badge(:problems, 3)
    expect(ui).to have_inline_overlay(line: 10, text: ": String")
    expect(ui).to have_gutter_marker(line: 5, kind: :breakpoint)
    expect(ui).to have_line_highlight(line: 12, kind: :debug_position)
  end

  it "reports available instrumentation on mismatch" do
    expect { expect(ui).to have_line_highlight(line: 13, kind: :debug_position) }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /syrma:decoration:line:12:debug_position/)
  end
end

RSpec.describe "Syrma terminal matcher", type: :zaniah do
  around do |example|
    old = ENV["SYRMA_SNAPSHOT_DIR"]
    Dir.mktmpdir("syrma-rspec-terminal") do |dir|
      ENV["SYRMA_SNAPSHOT_DIR"] = dir
      example.run
    end
  ensure
    old ? ENV["SYRMA_SNAPSHOT_DIR"] = old : ENV.delete("SYRMA_SNAPSHOT_DIR")
  end

  it "matches terminal snapshots" do
    zaniah_session(backend: :tui, width: 160, height: 60) { |window| window.draw { Zaniah::Text.new("Terminal") } }
    expect(ui).to match_terminal_snapshot("terminal")
  end
end
