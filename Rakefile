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

desc "Regenerate deterministic demo media"
task :demo do
  Dir["demo/*.rb"].sort.each { |path| ruby "-Ilib", "-I../wezen/lib", path }
end

task default: %i[test spec]
