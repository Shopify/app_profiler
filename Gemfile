# frozen_string_literal: true

source("https://rubygems.org")
gemspec

# Specify the same dependency sources as the application Gemfile
gem("activesupport", "~> 5.2")
gem("railties", "~> 5.2")
gem("vernier", "~> 0.4.0") if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.2.1")

gem("google-cloud-storage", "~> 1.21")
gem("rubocop", require: false)
gem("rubocop-shopify", require: false)
gem("rubocop-performance", require: false)
