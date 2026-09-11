# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rspec/core/rake_task"
require_relative "lib/syrma/rake_task"

Rake::TestTask.new(:test) do |test|
  test.libs << "lib" << "test"
  test.pattern = "test/**/*_test.rb"
end

RSpec::Core::RakeTask.new(:spec) { |spec| spec.rspec_opts = ["-Ilib"] }
Syrma::RakeTask.new

task default: %i[test spec]
