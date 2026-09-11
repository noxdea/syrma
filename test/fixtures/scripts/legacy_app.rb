# frozen_string_literal: true

count = 0
window = Zaniah::Platform.open_window(width: 160, height: 80, title: "Legacy")
window.draw do
  Zaniah::Div.new.w(100).h(30).test_id("legacy").on_click { count += 1 }
    .child(Zaniah::Text.new("Count: #{count}"))
end
window.run
$syrma_legacy_after_run = true
