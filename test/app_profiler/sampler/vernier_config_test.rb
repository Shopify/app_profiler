# frozen_string_literal: true

module AppProfiler
  module Sampler
    class VernieConfigTest < TestCase
      test "mode probabilities should sum to 1" do
        skip("Vernier not supported") unless AppProfiler.vernier_supported?

        assert_raises(ArgumentError) do
          VernierConfig.new(
            wall_mode_probability: 0.5,
            retained_mode_probability: 0.6,
          )
        end
      end

      test "default config" do
        skip("Vernier not supported") unless AppProfiler.vernier_supported?

        config = VernierConfig.new

        assert_equal(VernierConfig::WALL_MODE_PROBABILITY, config.modes_probability[:wall])
        assert_equal(VernierConfig::RETAINED_MODE_PROBABILITY, config.modes_probability[:retained])

        assert_equal(VernierConfig::WALL_INTERVAL, config.interval_for(:wall))
        assert_equal(VernierConfig::RETAINED_INTERVAL, config.interval_for(:retained))
      end
    end
  end
end
