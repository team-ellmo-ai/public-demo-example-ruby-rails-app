# frozen_string_literal: true

require_relative "lib/ellmo_ai/version"

Gem::Specification.new do |spec|
  spec.name = "ellmo-ai-rails"
  spec.version = EllmoAi::VERSION
  spec.authors = ["eLLMo AI"]
  spec.summary = "Add eLLMo AI's content (structured data and semantic HTML) to your Rails pages"
  spec.description = "Rack middleware and Rails helpers that put eLLMo AI's structured data and semantic HTML " \
                     "into the HTML your app serves, cached, and report page views in the background."
  spec.homepage = "https://www.tryellmo.ai?utm_source=rubygems&utm_medium=package&utm_campaign=ellmo-ai-rails"
  spec.license = "Nonstandard"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.2", "< 4"

  spec.metadata["rubygems_mfa_required"] = "true"
end
