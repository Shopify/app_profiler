# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class ConfigurationTest < TestCase
    include OtelHelper

    test "unexpected handler profile_enqueue_success raises ArgumentError " do
      assert_raises(ArgumentError) do
        AppProfiler.profile_enqueue_success = ->(_success) { nil }
      end
    end

    test "unexpected handler profile_enqueue_failure raises ArgumentError " do
      assert_raises(ArgumentError) do
        AppProfiler.profile_enqueue_failure = ->() { nil }
      end
    end

    test "unexpected handler after_process_queue raises ArgumentError " do
      assert_raises(ArgumentError) do
        AppProfiler.after_process_queue = lambda { nil }
      end
    end

    test "unexpected handler profile_sampler_enabled raises ArgumentError " do
      assert_raises(ArgumentError) do
        AppProfiler.profile_sampler_enabled = ->(arg) { arg }
      end
    end

    test "proc with args for profile_sampler_enabled raises ArgumentError " do
      assert_raises(ArgumentError) do
        AppProfiler.profile_sampler_enabled = ->(arg) { arg }
      end
    end

    test "profile_sampler_enabled allows TrueClass, FalseClass, Proc" do
      old_status = AppProfiler.profile_sampler_enabled
      AppProfiler.profile_sampler_enabled = false
      AppProfiler.profile_sampler_enabled = true
      AppProfiler.profile_sampler_enabled = -> { false }
    ensure
      AppProfiler.profile_sampler_enabled = old_status
    end

    test "profile_sampler_enabled is false if Proc raises" do
      old_status = AppProfiler.profile_sampler_enabled
      AppProfiler.profile_sampler_enabled = -> { raise "error" }
      assert_equal(false, AppProfiler.profile_sampler_enabled)
    ensure
      AppProfiler.profile_sampler_enabled = old_status
    end

    test "otel_instrumentation_enabled config works" do
      old_status = AppProfiler.otel_instrumentation_enabled

      AppProfiler.otel_instrumentation_enabled = true
      assert(AppProfiler.otel_instrumentation_enabled)

      AppProfiler.otel_instrumentation_enabled = false
      assert_equal(false, AppProfiler.otel_instrumentation_enabled)
    ensure
      AppProfiler.otel_instrumentation_enabled = old_status
    end

    test "enabling otel instrumentation loads opentelemetry-instrumentation-rack" do
      old_status = AppProfiler.otel_instrumentation_enabled
      AppProfiler.expects(:gem).with("opentelemetry-instrumentation-rack")
      AppProfiler.expects(:require).with("opentelemetry/instrumentation/rack")

      AppProfiler.otel_instrumentation_enabled = true

      assert(AppProfiler.otel_instrumentation_enabled)
      assert_equal(OpenTelemetry::Instrumentation::Rack, AppProfiler.otel_rack_instrumentation)
    ensure
      AppProfiler.instance_variable_set(:@otel_instrumentation_enabled, old_status)
    end

    test "enabling otel instrumentation with opentelemetry-shopify 2.0 loaded does not load opentelemetry-instrumentation-rack" do
      old_status = AppProfiler.otel_instrumentation_enabled
      with_shopify_rack_instrumentation do |shopify_rack|
        AppProfiler.expects(:gem).never
        AppProfiler.expects(:require).never

        AppProfiler.otel_instrumentation_enabled = true

        assert(AppProfiler.otel_instrumentation_enabled)
        assert_equal(shopify_rack, AppProfiler.otel_rack_instrumentation)
      end
    ensure
      AppProfiler.instance_variable_set(:@otel_instrumentation_enabled, old_status)
    end

    test "enabling otel instrumentation works with opentelemetry-shopify 2.0 in the bundle before it is loaded" do
      old_status = AppProfiler.otel_instrumentation_enabled
      without_contrib_rack_instrumentation do
        AppProfiler.expects(:gem).with("opentelemetry-instrumentation-rack")
          .raises(Gem::LoadError, "opentelemetry-instrumentation-rack is not part of the bundle.")
        AppProfiler.expects(:require).never
        loaded_specs = Gem.loaded_specs.merge("opentelemetry-shopify" => Gem::Specification.new)
        Gem.stubs(:loaded_specs).returns(loaded_specs)

        AppProfiler.otel_instrumentation_enabled = true

        assert(AppProfiler.otel_instrumentation_enabled)
        assert_nil(AppProfiler.otel_rack_instrumentation)

        with_shopify_rack_instrumentation do |shopify_rack|
          assert_equal(shopify_rack, AppProfiler.otel_rack_instrumentation)
        end
      end
    ensure
      AppProfiler.instance_variable_set(:@otel_instrumentation_enabled, old_status)
    end

    test "enabling otel instrumentation without opentelemetry-shopify or opentelemetry-instrumentation-rack raises" do
      old_status = AppProfiler.otel_instrumentation_enabled
      AppProfiler.otel_instrumentation_enabled = false
      without_contrib_rack_instrumentation do
        AppProfiler.expects(:gem).with("opentelemetry-instrumentation-rack")
          .raises(Gem::LoadError, "opentelemetry-instrumentation-rack is not part of the bundle.")
        AppProfiler.expects(:require).never
        loaded_specs = Gem.loaded_specs.except("opentelemetry-shopify")
        Gem.stubs(:loaded_specs).returns(loaded_specs)

        error = assert_raises(Gem::LoadError) do
          AppProfiler.otel_instrumentation_enabled = true
        end

        assert_match("opentelemetry-instrumentation-rack", error.message)
        assert_equal(false, AppProfiler.otel_instrumentation_enabled)
        assert_nil(AppProfiler.otel_rack_instrumentation)
      end
    ensure
      AppProfiler.instance_variable_set(:@otel_instrumentation_enabled, old_status)
    end

    test "otel_rack_instrumentation prefers opentelemetry-shopify 2.0 over opentelemetry-instrumentation-rack" do
      assert_equal(OpenTelemetry::Instrumentation::Rack, AppProfiler.otel_rack_instrumentation)

      with_shopify_rack_instrumentation do |shopify_rack|
        assert_equal(shopify_rack, AppProfiler.otel_rack_instrumentation)
      end

      assert_equal(OpenTelemetry::Instrumentation::Rack, AppProfiler.otel_rack_instrumentation)
    end
  end
end
