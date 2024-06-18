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
  end
end
