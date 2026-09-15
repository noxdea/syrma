# frozen_string_literal: true

module InstrumentedUIApp
  Z = Zaniah

  def self.mount(window)
    inline = Z::Text.new(": String").test_id("syrma:decoration:inline:10")
    source = Z::Text.new("value")
    source.inline_overlay(offset: 5, element: inline) if source.respond_to?(:inline_overlay)
    window.draw do
      root = Z::Div.new.flex_col.p(8).gap(4)
        .child(Z::Div.new.h(32).test_id("syrma:panel:problems")
          .child(Z::Text.new("Problems"))
          .child(Z::Text.new("3").test_id("syrma:panel:problems:badge")))
        .child(source)
        .child(Z::Div.new.h(4).w(4).test_id("syrma:decoration:gutter:0:breakpoint"))
        .child(Z::Div.new.h(4).w(4).test_id("syrma:decoration:gutter:5:breakpoint"))
        .child(Z::Div.new.h(20).w(120).test_id("syrma:decoration:line:12:debug_position"))
        .child(Z::Div.new.w(0).h(0).overflow_hidden
          .child(Z::Div.new.h(4).w(4).test_id("syrma:decoration:gutter:9:breakpoint")))
      root.child(inline) unless source.respond_to?(:inline_overlay)
      root
    end
  end
end
