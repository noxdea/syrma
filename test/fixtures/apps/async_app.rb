# frozen_string_literal: true

module AsyncApp
  def self.mount(app, window)
    result = +"loading"
    window.draw do
      Zaniah::Div.new.on_click do
        app.executor.background { sleep 0.02; "done" }
          .on_complete { app.executor.post { result.replace("done"); window.request_frame } }
      end.child(Zaniah::Text.new("State: #{result}"))
    end
  end
end
