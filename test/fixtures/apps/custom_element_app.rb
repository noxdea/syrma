# frozen_string_literal: true

module CustomElementApp
  class CustomButton < Zaniah::Div
    def prepaint(bounds, state, context) = super
  end

  def self.mount(window)
    clicked = []
    window.draw { CustomButton.new.w(80).h(30).test_id("custom").on_click { clicked << true } }
    clicked
  end
end
