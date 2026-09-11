# frozen_string_literal: true

module Syrma
  module TreeFormat
    DEFAULT = %i[test_id text bounds bg handlers tooltip].freeze

    module_function

    def dump(node, attributes: DEFAULT, depth: 0, out: +"")
      parts = [node.type.to_s]
      parts << "@#{node.test_id}" if attributes.include?(:test_id) && node.test_id
      parts << node.text.inspect if attributes.include?(:text) && node.text
      if attributes.include?(:bounds)
        bounds = node.bounds
        parts << "[#{num(bounds.x)},#{num(bounds.y)} #{num(bounds.width)}x#{num(bounds.height)}]"
      end
      parts << "bg=#{node.background}" if attributes.include?(:bg) && node.background && node.background != "#0000"
      parts << "on=#{node.handlers.join(',')}" if attributes.include?(:handlers) && node.handlers.any?
      parts << "tooltip=#{node.tooltip.inspect}" if attributes.include?(:tooltip) && node.tooltip
      out << ("  " * depth) << parts.join(" ") << "\n"
      node.children.each { |child| dump(child, attributes: attributes, depth: depth + 1, out: out) }
      out
    end

    def num(value)
      rounded = value.to_f.round(2)
      rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
    end
  end
end
