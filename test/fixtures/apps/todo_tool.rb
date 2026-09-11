# frozen_string_literal: true

module TodoTool
  Z = Zaniah

  def self.mount(window)
    items = []
    draft = +""
    window.on_input do |event|
      case event
      when Z::Input::TextInput then draft << event.text
      when Z::Input::KeyDown
        if event.keystroke == "enter" && !draft.empty?
          items << draft.dup
          draft.clear
        end
      end
    end
    window.draw do
      Z::Div.new.flex_col.p(16).gap(8).bg("#161b22")
        .child(Z::Text.new("Input: #{draft}").test_id("draft"))
        .children(items.each_with_index.map do |item, index|
          Z::Div.new.flex_row.gap(8).test_id("item-#{index}")
            .child(Z::Text.new(item))
            .child(Z::Div.new.w(24).h(20).bg("#633").tooltip("Delete")
              .on_click { items.delete_at(index) }
              .child(Z::Text.new("×")))
        end)
    end
  end
end
