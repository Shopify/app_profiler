# frozen_string_literal: true

source("https://rubygems.org")
gemspec

# Specify the same dependency sources as the application Gemfile
rails_version = ENV.fetch("RAILS_VERSION", "7.2")

gem("activesupport", "~> #{rails_version}.0")
gem("railties", "~> #{rails_version}.0")
gem("rack", "~> 2.2.0")
gem("vernier", "~> 1.10.0")

gem("google-cloud-storage", "~> 1.21")
gem("rubocop", "~> 1.64.1", require: false)
gem("rubocop-shopify", "~> 2.15.1", require: false)
gem("rubocop-performance", "~> 1.6.0", require: false)
gem("debug")
