# frozen_string_literal: true

module Syrma
  class Error < Zaniah::Error; end
  class UnstableUI < Error; end
  class WaitTimeout < Error; end
  class SnapshotMissing < Error; end
  class SnapshotMismatch < Error; end
  class UnsupportedBackend < Error; end

  class ElementNotFound < Error
    def initialize(locator, tree)
      texts = tree.text_runs.map { |run| run[2] }.uniq.first(10)
      super("Element not found: #{locator}\n  Visible text: #{texts.inspect}")
    end
  end

  class AmbiguousMatch < Error
    def initialize(locator, nodes)
      super("Matched #{nodes.length} elements: #{locator}\n  " +
            nodes.first(5).map(&:inspect).join("\n  ") + "\n  Refine with nth, first, or within")
    end
  end

  class NotActionable < Error
    attr_reader :reason

    def initialize(reason, message)
      @reason = reason
      super(message)
    end
  end
end
