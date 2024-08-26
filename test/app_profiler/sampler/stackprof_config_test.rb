# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Sampler
    class StackprofConfigTest < TestCase
      test "mode probabilities should sum to 1" do
        assert_raises(ArgumentError) do
          StackprofConfig.new(
            wall_mode_probability: 0.5,
            cpu_mode_probability: 0.5,
            object_mode_probability: 0.5,
          )
        end
      end

      test "default config" do
        config = StackprofConfig.new

        assert_equal(StackprofConfig::WALL_MODE_PROBABILITY, config.modes_probability[:wall])
        assert_equal(StackprofConfig::CPU_MODE_PROBABILITY, config.modes_probability[:cpu])
        assert_equal(StackprofConfig::OBJECT_MODE_PROBABILITY, config.modes_probability[:object])

        assert_equal(StackprofConfig::WALL_INTERVAL, config.interval_for(:wall))
        assert_equal(StackprofConfig::CPU_INTERVAL, config.interval_for(:cpu))
        assert_equal(StackprofConfig::OBJECT_INTERVAL, config.interval_for(:object))
      end
    end
  end
end
