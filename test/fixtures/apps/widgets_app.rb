# frozen_string_literal: true

module WidgetsApp
  Z = Zaniah

  def self.mount(window)
    state = {x: 0.0, dropped: [], composing: "", committed: +"", resized: nil, picked: []}
    list = Z::List.new(count: 200, estimated_height: 20) do |index|
      Z::Div.new.h(20).test_id("row-#{index}").child(Z::Text.new("row #{index}"))
    end
    window.on_input do |event|
      case event
      when Z::Input::FileDrop then state[:dropped].concat(event.paths)
      when Z::Input::Composition then state[:composing] = event.text
      when Z::Input::TextInput then state[:committed] << event.text; state[:composing] = ""
      end
    end
    window.on_resize { |size| state[:resized] = [size.width, size.height] }
    window.draw do
      Z::Div.new.flex_row.w_full.h_full
        .child(Z::Div.new.w(150).h_full.test_id("list-wrap").child(list.h(200).test_id("list")))
        .child(Z::Div.new.flex_1.flex_col.p(8).gap(6)
          .child(Z::Div.new.w(20).h(20).bg("#48c").test_id("knob")
            .on_drag { |event, _| state[:x] = event.position.x }
            .context_menu([["Copy", -> { state[:picked] << :copy }], ["Disabled", nil],
                           ["Paste", -> { state[:picked] << :paste }]]))
          .child(Z::Text.new("x=#{state[:x].round}"))
          .child(Z::Text.new("ime=#{state[:composing]}|#{state[:committed]}"))
          .child(Z::Text.new("dropped=#{state[:dropped].join(',')}")))
    end
    state
  end
end
