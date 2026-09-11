# frozen_string_literal: true

ENV["MT_NO_PLUGINS"] = "1"
gem "minitest", "~> 5.0"
require "minitest/autorun"
require "stringio"
require "syrma/minitest"
Dir[File.expand_path("fixtures/apps/*.rb", __dir__)].sort.each { |path| require path }
