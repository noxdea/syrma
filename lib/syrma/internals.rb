# frozen_string_literal: true

module Syrma
  module Internals
    module_function

    def style(element) = element.instance_variable_get(:@style) || {}
    def background(element) = element.instance_variable_get(:@background)
    def border_color(element) = element.instance_variable_get(:@border_color)
    def radius(element) = element.instance_variable_get(:@radius)
    def tooltip(element) = element.instance_variable_get(:@tooltip)
    def context_menu(element) = element.instance_variable_get(:@context_menu)
    def key(element) = element.instance_variable_get(:@key)
    def shown_tooltip(window)
      tip = window.instance_variable_get(:@tooltip)
      tip && tip[:shown] ? tip[:text] : nil
    end

    def bundled_font_path
      _, entry = $LOAD_PATH.resolve_feature_path("zaniah")
      File.expand_path("../assets/fonts/Abel-Regular.ttf", File.dirname(entry))
    end

    def executor_idle?(executor) = executor.instance_variable_get(:@foreground).empty?
  end
end
