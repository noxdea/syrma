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

  Tree = Data.define(:frame, :size, :root, :nodes, :hits, :text_runs, :menu, :menu_index, :tooltip, :hit_regions) do
    def hit_at(point, event: :mouse_down, button: :left)
      hits.length.times.reverse_each do |index|
        _bounds, node = hits[index]
        next unless hit_regions[index].contains?(point)

        return node if node.nil? || Tree.handles?(node, event, button)
      end
      nil
    end

    def self.handles?(node, event, button)
      case event
      when :mouse_down
        (button == :right && node.element.respond_to?(:context_menu_items) && node.element.context_menu_items) ||
          (node.handlers & %i[mouse_down click drag]).any?
      when :mouse_move then node.handlers.include?(:hover) || node.tooltip
      when :mouse_up then node.handlers.include?(:mouse_up)
      when :scroll then node.handlers.include?(:scroll_wheel)
      end
    end
  end

  class SnapshotBuilder
    def build(window)
      snapshot = Zaniah::Inspection.snapshot(window)
      by_element = {}.compare_by_identity
      nodes = []
      viewport = Zaniah::Bounds.new(0, 0, window.content_size.width, window.content_size.height)
      root = snapshot.root && visit(snapshot.root, viewport, [0], nodes, by_element)
      hits = snapshot.hits.map { |hit| [hit.bounds, hit.owner && by_element[hit.owner]] }
      popup = snapshot.overlays.popup
      tooltip = snapshot.overlays.tooltip
      Tree.new(frame: snapshot.frame.number, size: window.content_size, root: root,
               nodes: nodes.freeze, hits: hits.freeze, hit_regions: snapshot.hits, text_runs: snapshot.text_runs,
               menu: popup&.labels, menu_index: popup&.selected_index,
               tooltip: tooltip && tooltip[:shown] ? tooltip[:text] : nil)
    end

    private

    def visit(entry, clip, path, nodes, by_element)
      bounds = entry.bounds or return nil
      style = entry.style
      return nil if style[:display] == :none

      visible = bounds.intersect(clip)
      child_clip = style[:overflow] == :visible ? clip : visible
      index = nodes.length
      nodes << nil
      children = entry.children.each_with_index.filter_map do |child, child_index|
        visit(child, child_clip, path + [child_index], nodes, by_element)
      end
      element = entry.element
      node = Node.new(
        path: path.freeze, element: element, type: entry.type.split("::").last.downcase.to_sym,
        test_id: entry.test_id, key: entry.key,
        text: text_attr(element, :text), color: text_attr(element, :text_color),
        font_size: text_attr(element, :font_size), bounds: bounds, visible_bounds: visible,
        background: style[:background], border_color: style[:border_color],
        radius: style[:corner_radii], handlers: entry.handlers,
        tooltip: entry.tooltip, children: children.freeze
      )
      nodes[index] = node
      by_element[element] = node
    end

    def text_attr(element, name) = element.is_a?(Zaniah::Text) ? element.public_send(name) : nil
  end
end
