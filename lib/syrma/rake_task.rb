# frozen_string_literal: true

require "rake"
require_relative "cli"

module Syrma
  class RakeTask
    include Rake::DSL

    def initialize
      namespace :syrma do
        desc "Check the Syrma and Zaniah environment"
        task(:doctor) { abort unless CLI.run(["doctor"]).zero? }

        namespace :snapshots do
          desc "Update snapshot goldens"
          task(:update) { abort unless CLI.run(["snapshots", "update"]).zero? }

          desc "Prune unused snapshot goldens"
          task(:prune) { abort unless CLI.run(["snapshots", "prune"]).zero? }
        end

        desc "Build an HTML failure report"
        task(:report) { abort unless CLI.run(["report"]).zero? }
      end
    end
  end
end
