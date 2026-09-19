# frozen_string_literal: true

require "zaniah"
require_relative "syrma/version"
require_relative "syrma/configuration"
require_relative "syrma/errors"
require_relative "syrma/internals"
require_relative "syrma/instrumentation"
require_relative "syrma/clock"
require_relative "syrma/text_systems"
require_relative "syrma/snapshot"
require_relative "syrma/query"
require_relative "syrma/ui_assertions"
require_relative "syrma/event_log"
require_relative "syrma/event_codec"
require_relative "syrma/recorder"
require_relative "syrma/window_driver"
require_relative "syrma/recording"
require_relative "syrma/popup_driver"
require_relative "syrma/session"
require_relative "syrma/visual/comparator"
require_relative "syrma/visual/image"
require_relative "syrma/snapshots/store"
require_relative "syrma/snapshots/tree_format"
require_relative "syrma/snapshots/terminal_format"
require_relative "syrma/diagnostics"
require_relative "syrma/codegen"
require_relative "syrma/script_launcher"
require_relative "syrma/report"

module Syrma
  class << self
    attr_writer :configuration

    def configuration = (@configuration ||= Configuration.new)
    def configure = yield(configuration)
    def reset_configuration! = self.configuration = Configuration.new
  end
end
