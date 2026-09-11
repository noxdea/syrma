# frozen_string_literal: true

require_relative "../syrma"

module Syrma
  module Minitest
    def zaniah_session(**options, &mount)
      (@zaniah_sessions ||= []) << Session.new(**options, &mount)
      @zaniah_sessions.last
    end

    def ui = @zaniah_sessions&.last || raise(Error, "call zaniah_session first")

    def assert_ui_text(expected, session: ui, timeout: session.timeout)
      ui_eventually(session, timeout, -> { "Expected text #{expected.inspect} to appear (current: #{session.texts.inspect})" }) do
        session.texts.any? { |text| text_match?(text, expected) }
      end
    end

    def refute_ui_text(unexpected, session: ui, timeout: session.timeout)
      ui_eventually(session, timeout, -> { "Expected text #{unexpected.inspect} to disappear" }) do
        session.texts.none? { |text| text_match?(text, unexpected) }
      end
    end

    def assert_element(target = nil, count: nil, session: ui, **criteria)
      target = criteria unless criteria.empty?
      locator = locator_for(target, session)
      if count
        ui_eventually(session, session.timeout, -> { "Expected #{count} matches for #{locator} (current: #{locator.count})" }) do
          locator.count == count
        end
      else
        ui_eventually(session, session.timeout, -> { "Could not find #{locator}" }) { locator.exists? }
      end
    end

    def refute_element(target = nil, session: ui, **criteria)
      target = criteria unless criteria.empty?
      locator = locator_for(target, session)
      ui_eventually(session, session.timeout, -> { "Expected #{locator} to disappear" }) { !locator.exists? }
    end

    def assert_visible(target = nil, session: ui, **criteria)
      target = criteria unless criteria.empty?
      locator = locator_for(target, session)
      ui_eventually(session, session.timeout, -> { "Expected #{locator} to be visible" }) { locator.visible? }
    end

    def assert_hidden(target = nil, session: ui, **criteria)
      target = criteria unless criteria.empty?
      locator = locator_for(target, session)
      ui_eventually(session, session.timeout, -> { "Expected #{locator} to be hidden" }) { !locator.visible? }
    end

    def assert_clickable(target = nil, session: ui, **criteria)
      target = criteria unless criteria.empty?
      locator = locator_for(target, session)
      reason = nil
      ui_eventually(session, session.timeout, -> { "#{locator} is not clickable: #{reason}" }) do
        node = locator.resolve
        session.driver.__send__(:check_actionable, session.tree, node, :mouse_down, :left)
      rescue ElementNotFound, NotActionable => error
        reason = error.message
        false
      end
    end

    def assert_bg(target, color, session: ui)
      locator = locator_for(target, session)
      ui_eventually(session, session.timeout, -> { "Expected #{locator} background to be #{color.inspect}" }) do
        locator.resolve_all.any? { |node| Criteria.new(bg: color).match?(node) }
      end
    end

    def assert_pixel(x, y, color, threshold: 2, session: ui)
      expected = Zaniah::Color.parse(color).to_a.map { |channel| (channel * 255).round }
      actual = nil
      ui_eventually(session, session.timeout, -> { "Expected pixel (#{x}, #{y}) to be #{color.inspect} (current: #{actual.inspect})" }) do
        actual = session.pixel(x, y)
        actual.zip(expected).all? { |left, right| (left - right).abs <= threshold }
      end
    end

    def assert_tooltip(expected, session: ui)
      ui_eventually(session, session.timeout, -> { "Expected tooltip #{expected.inspect} (current: #{session.tooltip.inspect})" }) do
        text_match?(session.tooltip, expected)
      end
    end

    def assert_menu_items(labels, session: ui)
      ui_eventually(session, session.timeout, -> { "Expected menu items #{labels.inspect} (current: #{session.menu.items.inspect})" }) do
        session.menu.items == labels
      end
    end

    def assert_screenshot(name, session: ui, **options)
      warn "syrma: text: :none does not render text in images" if session.text_mode == :none
      store = Snapshots::Store.new
      path = snapshot_path(store, name, "png")
      status = Visual.check_screenshot(session, store: store, path: path,
                                       artifacts: Diagnostics.dir_for(self.class.name, self.name), **options)
      warn_snapshot(status, path)
      pass
    rescue SnapshotMismatch, SnapshotMissing => error
      flunk error.message
    end

    def assert_tree_snapshot(name, root: nil, attributes: TreeFormat::DEFAULT, session: ui)
      node = root ? (root.is_a?(Locator) ? root.resolve : root) : session.tree.root
      assert_text_snapshot(name, "tree.txt", TreeFormat.dump(node, attributes: attributes))
    end

    def assert_terminal_snapshot(name, colors: false, session: ui)
      assert_text_snapshot(name, "term.txt", session.terminal_lines(colors: colors).join("\n") + "\n")
    end

    def assert_no_text_overlap(session: ui)
      overlaps = TerminalFormat.overlaps(session.tree.text_runs)
      assert_empty overlaps, "Terminal text overlaps: #{overlaps.map { |a, b, row| "#{a.inspect} / #{b.inspect} (row #{row})" }.join(', ')}"
    end

    def after_teardown
      unless passed? || skipped?
        @zaniah_sessions&.each_with_index do |session, index|
          suffix = index.zero? ? "" : "-#{index}"
          Diagnostics.write(session, Diagnostics.dir_for(self.class.name, "#{name}#{suffix}"),
                            message: failures.map(&:message).join("\n\n"))
        end
      end
      @zaniah_sessions&.each(&:close)
      @zaniah_sessions = nil
      super
    end

    private

    def locator_for(target, session)
      return session.find(**target) if target.is_a?(Hash)

      target
    end

    def text_match?(actual, expected)
      return false if actual.nil?

      expected.is_a?(Regexp) ? expected.match?(actual) : actual == expected
    end

    def ui_eventually(session, timeout, message, &condition)
      session.wait_for(message, timeout: timeout, &condition)
      pass
    rescue WaitTimeout => error
      flunk error.message
    end

    def snapshot_path(store, name, extension)
      test_file = self.class.instance_method(self.name.to_sym).source_location&.first || "unknown"
      store.path(test_file: test_file, test_class: self.class.name, name: name, ext: extension)
    end

    def assert_text_snapshot(name, extension, actual)
      store = Snapshots::Store.new
      path = snapshot_path(store, name, extension)
      if !File.exist?(path) || store.update?
        existed = File.exist?(path)
        flunk "Snapshot not found: #{path}" if !File.exist?(path) && store.ci? && !store.update?

        store.write(path, actual)
        warn_snapshot(existed ? :updated : :created, path)
        return pass
      end
      assert_equal File.read(path, encoding: "UTF-8"), actual, "Snapshot mismatch: #{path}"
    end

    def warn_snapshot(status, path)
      return if status == :matched

      warn "syrma: #{status == :created ? 'created' : 'updated'} snapshot: #{path}"
    end
  end
end
