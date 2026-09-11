# frozen_string_literal: true

module Syrma
  Node = Data.define(:path, :element, :type, :test_id, :key, :text, :color, :font_size,
                     :bounds, :visible_bounds, :background, :border_color, :radius,
                     :handlers, :tooltip, :children) do
    def visible? = visible_bounds.width.positive? && visible_bounds.height.positive?
    def clickable? = handlers.include?(:click) || handlers.include?(:mouse_down)
    def center = Zaniah::Point.new(visible_bounds.x + visible_bounds.width / 2.0,
                                   visible_bounds.y + visible_bounds.height / 2.0)
    def descendants = children.flat_map { |child| [child, *child.descendants] }
    def content_text = [text, *descendants.map(&:text)].compact.join(" ")
    def ancestor_of?(other) = other.path.length > path.length && other.path.first(path.length) == path
    def inspect = "#<#{type}#{test_id && " @#{test_id}"}#{text && " #{text.inspect}"} #{path.join('.')}>"
  end

  Tree = Data.define(:frame, :size, :root, :nodes, :hits, :text_runs, :menu, :menu_index, :tooltip) do
    def hit_at(point, event: :mouse_down, button: :left)
      hits.reverse_each do |bounds, node|
        next unless bounds.contains?(point)

        return node if node.nil? || Tree.handles?(node, event, button)
      end
      nil
    end

    def self.handles?(node, event, button)
      case event
      when :mouse_down
        (button == :right && Internals.context_menu(node.element)) ||
          (node.handlers & %i[mouse_down click drag]).any?
      when :mouse_move then node.handlers.include?(:hover) || node.tooltip
      when :mouse_up then node.handlers.include?(:mouse_up)
      when :scroll then node.handlers.include?(:scroll_wheel)
      end
    end
  end

  class SnapshotBuilder
    def build(window)
      by_element = {}.compare_by_identity
      nodes = []
      viewport = Zaniah::Bounds.new(0, 0, window.content_size.width, window.content_size.height)
      root = window.testing_root && visit(window.testing_root, viewport, [0], nodes, by_element)
      hits = window.dispatcher.hits.map { |hit| [hit.bounds, hit.owner && by_element[hit.owner]] }
      popup = window.popup
      Tree.new(frame: window.testing_frame, size: window.content_size, root: root,
               nodes: nodes.freeze, hits: hits.freeze, text_runs: window.text_runs.map(&:dup).freeze,
               menu: popup&.labels, menu_index: popup&.selected_index,
               tooltip: Internals.shown_tooltip(window))
    end

    private

    def visit(element, clip, path, nodes, by_element)
      bounds = element.layout_node&.bounds or return nil
      style = Internals.style(element)
      return nil if style[:display] == :none

      visible = bounds.intersect(clip)
      child_clip = style[:overflow] == :visible ? clip : visible
      index = nodes.length
      nodes << nil
      children = element.children.each_with_index.filter_map do |child, child_index|
        visit(child, child_clip, path + [child_index], nodes, by_element)
      end
      node = Node.new(
        path: path.freeze, element: element, type: element.class.name.split("::").last.downcase.to_sym,
        test_id: element.test_id, key: Internals.key(element),
        text: text_attr(element, :text), color: text_attr(element, :text_color),
        font_size: text_attr(element, :font_size), bounds: bounds, visible_bounds: visible,
        background: Internals.background(element), border_color: Internals.border_color(element),
        radius: Internals.radius(element), handlers: element.handlers,
        tooltip: Internals.tooltip(element), children: children.freeze
      )
      nodes[index] = node
      by_element[element] = node
    end

    def text_attr(element, name) = element.is_a?(Zaniah::Text) ? element.public_send(name) : nil
  end
end
