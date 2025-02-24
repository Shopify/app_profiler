# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "app_profiler/version"

Gem::Specification.new do |spec|
  spec.name          = "app_profiler"
  spec.version       = AppProfiler::VERSION
  # In alphabetical order.
  spec.authors       = [
    "Gannon McGibbon",
    "Jay Ching Lim",
    "João Júnior",
    "Jon Simpson",
    "Kevin Jalbert",
    "Scott Francis",
  ]
  spec.email         = ["gems@shopify.com"]
  spec.summary       = "Collect performance profiles for your Rails application."
  spec.homepage      = "https://github.com/Shopify/app_profiler"

  spec.files = Dir["lib/**/*.rb"]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.7"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.add_dependency("activesupport", ">= 5.2")
  spec.add_dependency("rack")
  spec.add_dependency("stackprof", "~> 0.2")

  spec.add_development_dependency("bundler")
  spec.add_development_dependency("minitest")
  spec.add_development_dependency("minitest-stub-const", "0.6")
  spec.add_development_dependency("mocha")
  spec.add_development_dependency("opentelemetry-instrumentation-rack")
  spec.add_development_dependency("rake")
end
