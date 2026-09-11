# frozen_string_literal: true

module Syrma
  class PopupDriver
    def initialize(driver) = @driver = driver
    def open? = !@driver.tree.menu.nil?
    def items = @driver.tree.menu || []
    def selected = open? ? items[@driver.tree.menu_index] : nil
    def dismiss = @driver.press("esc")

    def select(label, via: :keyboard)
      index = items.index(label) or raise Error, "Menu item not found: #{label.inspect} (#{items.inspect})"
      unless @driver.window.popup.enabled[index]
        raise NotActionable.new(:disabled, "Menu item #{label.inspect} is disabled")
      end

      via == :mouse ? select_by_mouse(index) : select_by_keyboard(index)
    end

    private

    def select_by_keyboard(index)
      items.length.times do
        break if @driver.tree.menu_index == index

        @driver.press("down")
      end
      @driver.press("enter")
    end

    def select_by_mouse(index)
      bounds = @driver.window.popup.bounds
      y = bounds.y + bounds.height.fdiv(items.length) * (index + 0.5)
      @driver.mouse_down(Zaniah::Point.new(bounds.x + bounds.width / 2.0, y))
    end
  end
end
