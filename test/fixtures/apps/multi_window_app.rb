# frozen_string_literal: true

module MultiWindowApp
  def self.open_windows(app)
    opened = false
    app.open_window(width: 200, height: 100, title: "Main") do
      Zaniah::Div.new.w(100).h(30).test_id("settings").on_click do
        next if opened

        opened = true
        app.open_window(width: 180, height: 90, title: "Settings") do
          Zaniah::Div.new.child(Zaniah::Text.new("Settings ready"))
        end
      end.child(Zaniah::Text.new("Open settings"))
    end
  end
end
