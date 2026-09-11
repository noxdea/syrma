# frozen_string_literal: true

require_relative "test_helper"

class NativeSmokeTest < Minitest::Test
  def test_click_and_text_on_native_backend
    skip "set SYRMA_NATIVE=1 to run" unless ENV["SYRMA_NATIVE"] == "1"

    backend = RUBY_PLATFORM.include?("darwin") ? :mac : RUBY_PLATFORM.match?(/mswin|mingw/) ? :windows : :linux
    window = Zaniah::Platform.open_window(backend: backend, width: 160, height: 80)
    count = 0
    window.draw do
      Zaniah::Div.new.w(100).h(30).test_id("native").on_click { count += 1 }
        .child(Zaniah::Text.new("Count: #{count}"))
    end
    session = Syrma::Session.attach(window, text: :native, raster: :eager)
    session.test_id("native").click
    assert_includes session.texts, "Count: 1"
  ensure
    window&.close
  end
end
