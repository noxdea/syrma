# frozen_string_literal: true

require "rspec/expectations"
require_relative "../syrma"

module Syrma
  module RSpec
    module Helpers
      def zaniah_session(**options, &mount)
        (@zaniah_sessions ||= []) << Session.new(**options, &mount)
        @zaniah_sessions.last
      end

      def ui = @zaniah_sessions&.last || raise(Error, "call zaniah_session first")
      def zaniah_sessions = @zaniah_sessions || []
    end

    class << self
      def eventually(session, timeout: session.timeout)
        session.wait_for(timeout: timeout) { yield }
        true
      rescue WaitTimeout
        false
      end

      def snapshot_path(name, extension)
        example = ::RSpec.current_example
        Snapshots::Store.new.path(test_file: example.file_path, test_class: example.example_group.description,
                                  name: name, ext: extension)
      end

      def text_snapshot(name, extension, actual)
        store = Snapshots::Store.new
        path = snapshot_path(name, extension)
        if !File.exist?(path) || store.update?
          raise SnapshotMissing, "Snapshot not found: #{path}" if !File.exist?(path) && store.ci? && !store.update?

          store.write(path, actual)
          return true
        end
        File.read(path, encoding: "UTF-8") == actual
      end
    end

    ::RSpec::Matchers.define :have_ui_text do |expected|
      match do |session|
        RSpec.eventually(session) { session.texts.any? { |text| expected.is_a?(Regexp) ? expected.match?(text) : text == expected } }
      end
      match_when_negated do |session|
        RSpec.eventually(session) { session.texts.none? { |text| expected.is_a?(Regexp) ? expected.match?(text) : text == expected } }
      end
      failure_message { |session| "Expected text #{expected.inspect} to appear (current: #{session.texts.inspect})" }
      failure_message_when_negated { "Expected text #{expected.inspect} to disappear" }
    end

    ::RSpec::Matchers.define :have_element do |**criteria|
      match { |session| RSpec.eventually(session) { session.find(**criteria).exists? } }
      match_when_negated { |session| RSpec.eventually(session) { !session.find(**criteria).exists? } }
      failure_message { "Element not found: find(#{Criteria.new(criteria)})" }
    end

    ::RSpec::Matchers.define :be_visible do
      match { |locator| RSpec.eventually(locator.driver.session) { locator.visible? } }
      failure_message { |locator| "#{locator} is not visible" }
    end

    ::RSpec::Matchers.define :be_clickable do
      match do |locator|
        RSpec.eventually(locator.driver.session) do
          node = locator.resolve
          locator.driver.__send__(:check_actionable, locator.driver.tree, node, :mouse_down, :left)
        rescue ElementNotFound, NotActionable => error
          @reason = error.message
          false
        end
      end
      failure_message { |locator| "#{locator} is not clickable: #{@reason}" }
    end

    ::RSpec::Matchers.define :have_bg do |color|
      match { |locator| RSpec.eventually(locator.driver.session) { locator.resolve_all.any? { |node| Criteria.new(bg: color).match?(node) } } }
      failure_message { |locator| "Expected #{locator} background to be #{color.inspect}" }
    end

    ::RSpec::Matchers.define :have_pixel do |x, y, color, threshold: 2|
      match do |session|
        expected = Zaniah::Color.parse(color).to_a.map { |channel| (channel * 255).round }
        RSpec.eventually(session) do
          session.pixel(x, y).zip(expected).all? { |left, right| (left - right).abs <= threshold }
        end
      end
      failure_message { "Expected pixel (#{x}, #{y}) to be #{color.inspect}" }
    end

    ::RSpec::Matchers.define :have_tooltip do |text|
      match { |session| RSpec.eventually(session) { session.tooltip == text } }
      failure_message { |session| "Expected tooltip #{text.inspect} (current: #{session.tooltip.inspect})" }
    end

    ::RSpec::Matchers.define :have_menu_items do |labels|
      match { |session| RSpec.eventually(session) { session.menu.items == labels } }
      failure_message { |session| "Expected menu items #{labels.inspect} (current: #{session.menu.items.inspect})" }
    end

    ::RSpec::Matchers.define :match_screenshot do |name, **options|
      match do |session|
        store = Snapshots::Store.new
        path = RSpec.snapshot_path(name, "png")
        example = ::RSpec.current_example
        Visual.check_screenshot(session, store: store, path: path,
                                artifacts: Diagnostics.dir_for("RSpec", "#{example.full_description}-0"), **options)
        true
      rescue SnapshotMismatch, SnapshotMissing => error
        @reason = error.message
        false
      end
      failure_message { @reason }
    end

    ::RSpec::Matchers.define :match_tree_snapshot do |name, root: nil, attributes: TreeFormat::DEFAULT|
      match do |session|
        node = root ? (root.is_a?(Locator) ? root.resolve : root) : session.tree.root
        RSpec.text_snapshot(name, "tree.txt", TreeFormat.dump(node, attributes: attributes))
      rescue SnapshotMissing => error
        @reason = error.message
        false
      end
      failure_message { @reason || "Tree snapshot mismatch" }
    end

    ::RSpec::Matchers.define :match_terminal_snapshot do |name, colors: false|
      match do |session|
        RSpec.text_snapshot(name, "term.txt", session.terminal_lines(colors: colors).join("\n") + "\n")
      rescue SnapshotMissing => error
        @reason = error.message
        false
      end
      failure_message { @reason || "Terminal snapshot mismatch" }
    end
  end
end

::RSpec.configure do |config|
  config.include Syrma::RSpec::Helpers, type: :zaniah
  config.after(type: :zaniah) do |example|
    zaniah_sessions.each_with_index do |session, index|
      next unless example.exception

      Syrma::Diagnostics.write(session, Syrma::Diagnostics.dir_for("RSpec", "#{example.full_description}-#{index}"),
                               message: example.exception.message)
    end
    zaniah_sessions.each(&:close)
  end
end
