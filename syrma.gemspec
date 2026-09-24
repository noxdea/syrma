# frozen_string_literal: true

require_relative "lib/syrma/version"

Gem::Specification.new do |spec|
  spec.name = "syrma"
  spec.version = Syrma::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]
  spec.summary = "UI testing toolkit for applications built with Zaniah"
  spec.description = "Drive Zaniah windows headlessly: locate elements, send real input events, and assert text, layout, pixels, and snapshots."
  spec.homepage = "https://github.com/noxdea/syrma"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }
  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,sig,exe}/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"].select { |path| File.file?(path) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}).map { |path| File.basename(path) }
  spec.require_paths = ["lib"]
  spec.add_dependency "zaniah", ">= 0.7", "< 1.0"
  spec.add_dependency "wezen", ">= 0.1", "< 0.2"
end
