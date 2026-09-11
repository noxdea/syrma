# frozen_string_literal: true

module AnimationApp
  def self.mount(window)
    frame = 0
    window.on_tick { frame += 1 }
    window.draw { window.request_frame; Zaniah::Text.new("Frame: #{frame}") }
  end
end
