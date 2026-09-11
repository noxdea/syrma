# frozen_string_literal: true

module Syrma
  class WindowDriver
    I = Zaniah::Input

    attr_reader :window, :session

    def initialize(window, session)
      @window = window
      @session = session
      Instrumentation.capture(window, lazy_raster: session.raster == :lazy)
      @builder = SnapshotBuilder.new
    end

    def strict = session.strict

    def tree
      session.settle
      @tree = nil if @tree && @tree.frame != window.testing_frame
      @tree ||= @builder.build(window)
    end

    def find(**conditions, &predicate) = Locator.new(self, Criteria.new(conditions, predicate))
    def all(**conditions, &predicate) = find(**conditions, &predicate).resolve_all
    def test_id(id) = find(test_id: id)
    def text(value) = find(text: value)
    def texts = tree.text_runs.map { |run| run[2] }
    def tooltip = tree.tooltip

    def button(label)
      find(clickable: true) do |node|
        node.content_text == label &&
          node.descendants.none? { |descendant| descendant.clickable? && descendant.content_text == label }
      end
    end

    def at(x, y = nil, event: :mouse_down, button: :left)
      point = x.is_a?(Zaniah::Point) ? x : Zaniah::Point.new(x, y)
      tree.hit_at(point, event: event, button: button)
    end

    def pixel(x, y)
      width = window.content_size.width.to_i
      height = window.content_size.height.to_i
      x = Integer(x)
      y = Integer(y)
      raise RangeError, "Pixel coordinates are out of bounds: #{x},#{y}" unless x.between?(0, width - 1) && y.between?(0, height - 1)

      session.screenshot_pixels(self).byteslice((y * width + x) * 4, 4).bytes
    end

    def screenshot(path = nil)
      width = window.content_size.width.to_i
      height = window.content_size.height.to_i
      pixels = session.screenshot_pixels(self)
      return pixels unless path

      Zaniah::PNG.write(path, width, height, pixels)
      path
    end

    def terminal_lines(colors: false)
      raise UnsupportedBackend, "terminal_lines is only available for TUI sessions" unless session.tui?(self)

      session.settle
      TerminalFormat.lines(session.output_for(self).string, colors: colors)
    end

    def click(target = nil, button: :left, modifiers: [], count: 1, offset: nil, force: false, **criteria)
      target = criteria unless criteria.empty?
      point = actionable_point(target, :mouse_down, button, force, offset)
      gesture do
        dispatch I::MouseMove.new(point, modifiers)
        dispatch I::MouseDown.new(point, button, modifiers, count)
        dispatch I::MouseUp.new(point, button, modifiers)
      end
    end

    def double_click(target, **options)
      click(target, **options, count: 1)
      click(target, **options, count: 2)
    end

    def right_click(target, **options) = click(target, **options, button: :right)
    def hover(target) = dispatch(I::MouseMove.new(actionable_point(target, :mouse_move, :left, false, nil), []))

    def drag(from, to, steps: 8, button: :left, modifiers: [])
      raise ArgumentError, "steps must be a positive integer" unless steps.is_a?(Integer) && steps.positive?

      start = actionable_point(from, :mouse_down, button, false, nil)
      finish = point_for(to)
      gesture do
        dispatch I::MouseMove.new(start, modifiers)
        dispatch I::MouseDown.new(start, button, modifiers, 1)
        1.upto(steps) do |index|
          ratio = index.fdiv(steps)
          dispatch I::MouseMove.new(
            Zaniah::Point.new(start.x + (finish.x - start.x) * ratio,
                              start.y + (finish.y - start.y) * ratio), modifiers
          )
        end
        dispatch I::MouseUp.new(finish, button, modifiers)
      end
    end

    def scroll(target, dx: 0, dy: 0, modifiers: [])
      point = actionable_point(target, :scroll, :left, false, nil)
      dispatch I::ScrollWheel.new(point, Zaniah::Point.new(dx, dy), nil, modifiers)
    end

    def mouse_move(point, modifiers: []) = dispatch(I::MouseMove.new(point_for(point), modifiers))
    def mouse_down(point, button: :left, modifiers: [], count: 1) = dispatch(I::MouseDown.new(point_for(point), button, modifiers, count))
    def mouse_up(point, button: :left, modifiers: []) = dispatch(I::MouseUp.new(point_for(point), button, modifiers))

    def press(*keystrokes)
      keystrokes.each do |stroke|
        normalized = I::Keystroke.normalize(stroke)
        gesture do
          dispatch I::KeyDown.new(normalized, false)
          dispatch I::KeyUp.new(normalized)
        end
      end
    end

    def key_down(stroke, held: false) = dispatch(I::KeyDown.new(I::Keystroke.normalize(stroke), held))
    def key_up(stroke) = dispatch(I::KeyUp.new(I::Keystroke.normalize(stroke)))

    def type(text, key_events: true)
      text.each_grapheme_cluster do |character|
        key = character == " " ? "space" : character.downcase
        gesture do
          dispatch I::KeyDown.new(key, false) if key_events
          dispatch I::TextInput.new(character)
          dispatch I::KeyUp.new(key) if key_events
        end
      end
    end

    def paste(text) = dispatch(I::TextInput.new(text))
    def compose(text, selection: nil) = dispatch(I::Composition.new(text, selection))
    def commit(text) = dispatch(I::TextInput.new(text))

    def drop_files(paths, at:)
      dispatch I::FileDrop.new(Array(paths).map(&:to_s), point_for(at))
    end

    def resize(width, height)
      window.resize(width, height)
      session.settle
    end

    def close = window.close

    def feed_terminal(bytes)
      raise UnsupportedBackend, "feed_terminal is only available for TUI sessions" unless window.respond_to?(:feed_input)

      window.feed_input(bytes)
      session.settle
    end

    def scroll_until(list, found:, step: 100, max: 50)
      target = find(**found)
      max.times do
        return target if target.exists? && target.resolve_all.any?(&:visible?)

        scroll(list, dy: step)
      end
      raise ElementNotFound.new(target, tree)
    end

    def menu = (@menu_driver ||= PopupDriver.new(self))

    def dispatch(event)
      session.event_log.add(window.testing_frame, window.title, event)
      window.input(event)
      session.settle unless @in_gesture && session.event_frames == :gesture
      event
    end

    def gesture
      outer = @in_gesture
      @in_gesture = true
      yield
    ensure
      @in_gesture = outer
      session.settle unless outer
    end

    private

    def normalize_target(target)
      return find(**target) if target.is_a?(Hash)
      return Zaniah::Point.new(*target) if target.is_a?(Array) && target.length == 2

      target
    end

    def resolve_node(target)
      target = normalize_target(target)
      target.is_a?(Locator) ? target.resolve : target
    end

    def point_for(target)
      target = normalize_target(target)
      return target if target.is_a?(Zaniah::Point)

      resolve_node(target).center
    end

    def actionable_point(target, event, button, force, offset)
      target = normalize_target(target)
      return target if target.is_a?(Zaniah::Point)

      last_error = nil
      session.wait_for(-> { "Target did not become actionable: #{target}\n  Last reason: #{last_error&.message}" }) do
        current_tree = tree
        node = target.is_a?(Locator) ? target.resolve(current_tree) : target
        point = offset ? offset_point(node, offset) : node.center
        force ? point : check_actionable(current_tree, node, event, button, point)
      rescue ElementNotFound, AmbiguousMatch, NotActionable => error
        raise if error.is_a?(AmbiguousMatch)

        last_error = error
        nil
      end
    end

    def offset_point(node, offset)
      x, y = offset.respond_to?(:x) ? [offset.x, offset.y] : offset
      Zaniah::Point.new(node.visible_bounds.x + x, node.visible_bounds.y + y)
    end

    def check_actionable(current_tree, node, event, button, preferred = nil)
      bounds = node.bounds
      unless bounds.width.positive? && bounds.height.positive?
        raise NotActionable.new(:invisible, "#{node.inspect} has zero size")
      end
      unless node.visible?
        raise NotActionable.new(:outside_viewport, "#{node.inspect} is outside the viewport or clipped by an ancestor")
      end
      raise NotActionable.new(:popup, "A context menu has captured input") if current_tree.menu

      points = preferred ? [preferred] : samples(node.visible_bounds)
      points.each do |point|
        hit = current_tree.hit_at(point, event: event, button: button)
        next if hit.nil?

        return point if hit.equal?(node) || node.ancestor_of?(hit) || hit.ancestor_of?(node)
      end
      blocker = current_tree.hit_at(preferred || node.center, event: event, button: button)
      reason = blocker ? :obscured : :no_handler
      message = blocker ? "#{node.inspect} is covered by #{blocker.inspect}" : "No element receives events at #{node.inspect}"
      raise NotActionable.new(reason, message)
    end

    def samples(bounds)
      [[0.5, 0.5], *[0.2, 0.5, 0.8].product([0.2, 0.5, 0.8])].uniq.map do |x, y|
        Zaniah::Point.new(bounds.x + bounds.width * x, bounds.y + bounds.height * y)
      end
    end
  end
end
