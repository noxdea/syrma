# frozen_string_literal: true

require "syrma"

RSpec.configure do |config|
  config.around(type: :zaniah) do |example|
    ci = ENV.delete("CI")
    example.run
  ensure
    ci ? ENV["CI"] = ci : ENV.delete("CI")
  end

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
