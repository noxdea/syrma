# frozen_string_literal: true

module CounterApp
  Z = Zaniah

  def self.mount(window, overlay: false)
    state = {count: 0, input: +"", saved: 0, picked: nil}
    focus = Z::Input::FocusHandle.new
    focus.on_action = ->(action) { state[:saved] += 1 if action == :save; true }
    window.dispatcher.focus(focus)
    window.on_input { |event| state[:input] << event.text if event.is_a?(Z::Input::TextInput) }
    window.draw do
      root = Z::Div.new.flex_col.p(16).gap(8).bg("#161b22")
        .child(Z::Text.new("Count: #{state[:count]}").test_id("label"))
        .child(Z::Div.new.w(80).h(28).bg("#345").rounded(4).test_id("inc").tooltip("Increment")
          .context_menu([["Reset", -> { state[:count] = 0 }], ["Disabled", nil]])
          .on_click { state[:count] += 1 }
          .child(Z::Text.new("+1")))
        .child(Z::Div.new.w(80).h(28).bg("#543").on_click { state[:count] -= 1 }.child(Z::Text.new("-1")))
        .child(Z::Text.new("Input: #{state[:input]}"))
        .child(Z::Text.new("Saved: #{state[:saved]}"))
      root.child(Z::Overlay.new.bg("#0008").on_click {}) if overlay
      root
    end
    state
  end
end
