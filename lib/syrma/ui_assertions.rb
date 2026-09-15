# frozen_string_literal: true

module Syrma
  module UIAssertions
    PREFIX = "syrma"
    ANY_TEXT = Object.new.freeze

    module_function

    def panel_id(id, badge: false) = [PREFIX, "panel", id, badge ? "badge" : nil].compact.join(":")

    def decoration_id(kind, line, type = nil)
      raise ArgumentError, "line must be a nonnegative integer" unless line.is_a?(Integer) && line >= 0

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
  end
end
