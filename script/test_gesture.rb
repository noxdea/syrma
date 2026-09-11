# frozen_string_literal: true

require "syrma"

Syrma.configure { |config| config.event_frames = :gesture }
Dir[File.expand_path("../test/**/*_test.rb", __dir__)].sort.each { |path| require path }
