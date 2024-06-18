# frozen_string_literal: true

ruby File.read(".ruby-version").strip

source("https://rubygems.org")
gemspec

# Specify the same dependency sources as the application Gemfile
gem("activesupport", "~> 5.2")
gem("railties", "~> 5.2")
gem("vernier", "~> 0.7.0")

gem("google-cloud-storage", "~> 1.21")
gem("rubocop", require: false)
gem("rubocop-shopify", require: false)
gem("rubocop-performance", require: false)
