# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "rails"
require "app_profiler"

require "active_support"
require "active_support/time_with_zone"
require "active_support/test_case"
require "active_support/testing/autorun"

require "mocha/minitest"
require "minitest/stub_const"

Pathname.new(__dir__).join("support").glob("**/*.rb").each do |file|
  require file
end

TEST_ROOT = Pathname.new(__dir__)
TMP_ROOT  = TEST_ROOT.join("..").join("tmp")
TMP_APP_ROOT = TMP_ROOT.join("app")

Time.zone = "Pacific Time (US & Canada)" # For Time.zone.now.
Time.zone_default = "Pacific Time (US & Canada)"

Mocha.configure do |config|
  config.stubbing_method_unnecessarily = :prevent
  config.stubbing_non_existent_method = :prevent
end

AppProfiler.tap do |config|
  config.logger       = Logger.new("/dev/null")
  config.root         = TMP_APP_ROOT
  config.profile_root = TMP_ROOT
end

module Vernier
  class FakeResult
    attr_accessor :meta, :data

    def initialize(data)
      @meta = data.delete(:metadata) || {}
      @data = data
    end

    def to_h
      {
        meta: @meta,
        data: @data,
      }
    end

    def write(out:)
      File.write(out, JSON.dump(to_h))
    end
  end
end

module AppProfiler
  class Dummy < Rails::Application; end

  class TestCase < ActiveSupport::TestCase
    include TestHelper

    protected

    def file_fixture(fixture)
      Pathname.new(TEST_ROOT).join("fixtures", fixture)
    end

    def stackprof_profile(params = {})
      { mode: :cpu, interval: 1000, frames: [], metadata: { id: "foo" } }.merge(params)
    end

    def vernier_profile(params = {})
      { meta: { product: "Ruby/Vernier", mode: "wall", markerSchema: [], sampleUnits: {}, categories: [] }, libs: [],
        threads: [], }.deep_merge(params)
    end

    def vernier_params(params = {})
      { mode: :wall, interval: 1000, metadata: { id: "foo" } }.merge(params)
    end

    def with_yarn_setup(app)
      old_yarn_setup = app.yarn_setup
      app.instance_variable_set(:@yarn_initialized, true)
      yield
    ensure
      app.instance_variable_set(:@yarn_initialized, old_yarn_setup)
    end
  end
end
