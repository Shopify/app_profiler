# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class ConfigurationTest < TestCase
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
  end
end
