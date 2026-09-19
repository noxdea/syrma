# frozen_string_literal: true

require "fileutils"
require "syrma"
require "wezen"

module SyrmaDemo
  module_function

  def mount(window)
    state = {count: 0, query: ""}
    window.draw do
      Zaniah::Div.new.flex_col.gap(12).p(24).bg("#111827")
        .child(Zaniah::Text.new("Syrma demo recording", size: 24, color: "#f9fafb"))
        .child(Zaniah::Text.new("Drive a deterministic headless UI", size: 14, color: "#9ca3af"))
        .child(Zaniah::Div.new.w(180).h(36).bg("#2563eb").rounded(6).test_id("increment")
          .on_click { state[:count] += 1 }.child(Zaniah::Text.new("Count: #{state[:count]}")))
        .child(Zaniah::Text.new("Query: #{state[:query]}", size: 14, color: "#d1d5db"))
    end
  end

  def run
    FileUtils.mkdir_p("docs/media")
    session = Syrma::Session.new(width: 640, height: 360, text: :deterministic) { |window| mount(window) }
    result = session.record(fps: 12, seed: 42, chrome: {cursor: true, keycaps: true}) do |recording|
      recording.frame
      recording.caption("Drive the UI through the real event path")
      recording.click_slowly([100, 110], approach: 0.3)
      recording.pause(0.4)
      recording.press_slowly("tab", gap: 0.15)
      recording.type_humanly("README.md", cps: 20)
      recording.pause(0.5)
    end
    result.write_apng("docs/media/overview.apng")
    result.write_png("docs/media/overview.png")
  ensure
    session&.close
  end
end

SyrmaDemo.run
