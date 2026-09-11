# frozen_string_literal: true

module Syrma
  class Criteria
    KEYS = %i[test_id key text has_text type clickable handler tooltip visible bg].freeze

    def initialize(conditions, predicate = nil)
      unknown = conditions.keys - KEYS
      raise ArgumentError, "Unknown search criteria: #{unknown.join(', ')}" unless unknown.empty?

      @conditions = conditions.freeze
      @predicate = predicate
    end

    def match?(node)
      @conditions.all? { |name, expected| __send__(:"match_#{name}", node, expected) } &&
        (@predicate.nil? || @predicate.call(node))
    end

    def to_s = @conditions.map { |key, value| "#{key}: #{value.inspect}" }.join(", ") + (@predicate ? " + block" : "")

    private

    def text_match(actual, expected)
      return false if actual.nil?

      expected.is_a?(Regexp) ? expected.match?(actual) : actual == expected
    end

    def match_test_id(node, value) = node.test_id == value.to_s
    def match_key(node, value) = node.key == value
    def match_text(node, value) = text_match(node.text, value)
    def match_has_text(node, value) = value.is_a?(Regexp) ? value.match?(node.content_text) : node.content_text.include?(value)
    def match_type(node, value) = value.is_a?(Class) ? node.element.is_a?(value) : node.type == value
    def match_clickable(node, value) = node.clickable? == value
    def match_handler(node, value) = node.handlers.include?(value)
    def match_tooltip(node, value) = text_match(node.tooltip, value)
    def match_visible(node, value) = node.visible? == value
    def match_bg(node, value) = !node.background.nil? && Zaniah::Color.parse(node.background).to_a == Zaniah::Color.parse(value).to_a
  end

  class Locator
    attr_reader :driver, :criteria, :scope, :index

    def initialize(driver, criteria, scope: nil, index: nil)
      @driver = driver
      @criteria = criteria
      @scope = scope
      @index = index
    end

    def find(**conditions, &predicate) = Locator.new(driver, Criteria.new(conditions, predicate), scope: self)
    def nth(index) = Locator.new(driver, criteria, scope: scope, index: index)
    def first = nth(0)
    def last = nth(-1)

    def candidates(tree = driver.tree)
      pool = scope ? scope.resolve_all(tree).flat_map(&:descendants) : tree.nodes
      pool.select { |node| criteria.match?(node) }
    end

    def resolve_all(tree = driver.tree)
      found = candidates(tree)
      index.nil? ? found : [found[index]].compact
    end

    def resolve(tree = driver.tree, strict: driver.strict)
      found = resolve_all(tree)
      raise ElementNotFound.new(self, tree) if found.empty?
      raise AmbiguousMatch.new(self, found) if strict && found.length > 1

      found.first
    end

    def count = resolve_all.length
    def exists? = count.positive?
    def visible? = resolve_all.any?(&:visible?)
    def text = resolve.content_text
    def click(**options) = driver.click(self, **options)
    def double_click(**options) = driver.double_click(self, **options)
    def hover = driver.hover(self)
    def right_click = driver.right_click(self)
    def to_s = "#{scope ? "#{scope} >> " : ''}find(#{criteria})#{index.nil? ? '' : "[#{index}]"}"
  end
end
