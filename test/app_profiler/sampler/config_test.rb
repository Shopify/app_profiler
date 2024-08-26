# frozen_string_literal: true

require "test_helper"
module AppProfiler
  module Sampler
    class ConfigTest < TestCase
      test "invalid sample_rate raises" do
        [1.1, -0.1].each do |sample_rate|
          assert_raises(ArgumentError) do
            Config.new(sample_rate: sample_rate)
          end
        end
      end

      test "backend_probabilities must sum to 1" do
        assert_raises(ArgumentError) do
          Config.new(backends_probability: { stackprof: 0.5, vernier: 0.51 })
        end
      end

      test "default config" do
        config = Config.new
        assert_equal(Config::SAMPLE_RATE, config.sample_rate)
        assert_equal(Config::PATHS, config.paths)
        assert_equal(Config::BACKEND_PROBABILITES, config.backends_probability)
        assert_not_nil(config.get_backend_config(:stackprof))
        assert_nil(config.get_backend_config(:vernier))
      end
    end
  end
end
