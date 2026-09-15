# frozen_string_literal: true

module Syrma
  module UIAssertions
    PREFIX = "syrma"
    ANY_TEXT = Object.new.freeze

    module_function

    def panel_id(id, badge: false) = [PREFIX, "panel", component(id, "panel id"), badge ? "badge" : nil].compact.join(":")

    def decoration_id(kind, line, type = nil)
      raise ArgumentError, "line must be a nonnegative integer" unless line.is_a?(Integer) && line >= 0

      kind = component(kind, "decoration kind")
      type = component(type, "decoration type") unless type.nil?
      [PREFIX, "decoration", kind, line, type].compact.join(":")
    end

    def visible?(session, test_id, text: ANY_TEXT)
      nodes(session, test_id).any? do |node|
        node.visible? && (text.equal?(ANY_TEXT) || text_match?(node.content_text, text))
      end
    end

    def describe(session, prefix)
      found = session.tree.nodes.select { |node| node.test_id&.start_with?(prefix) }
      return "none" if found.empty?

      found.first(10).map do |node|
        "#{node.test_id}=#{node.content_text.inspect} (#{node.visible? ? 'visible' : 'hidden'})"
      end.join(", ")
    end

    def nodes(session, test_id) = session.tree.nodes.select { |node| node.test_id == test_id }

    def text_match?(actual, expected)
      expected.is_a?(Regexp) ? expected.match?(actual) : actual == expected.to_s
    end

    def component(value, label)
      valid = value.is_a?(String) || value.is_a?(Symbol)
      value = value.to_s
      valid &&= !value.empty? && !value.include?(":") && !value.match?(/[\x00-\x1f\x7f]/)
      raise ArgumentError, "#{label} must be a nonempty string or symbol without colons or control characters" unless valid

      value
    end
    private_class_method :component
  end
end
