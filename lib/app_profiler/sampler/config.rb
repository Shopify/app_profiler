# frozen_string_literal: true

require "app_profiler/sampler/stackprof_config"
require "app_profiler/sampler/vernier_config"
module AppProfiler
  module Sampler
    class Config
      attr_reader :sample_rate, :targets, :exclude_targets, :cpu_interval, :backends_probability

      SAMPLE_RATE = 0.001 # 0.1%
      TARGETS = ["/"]
      BACKEND_PROBABILITES = { stackprof: 1.0, vernier: 0.0 }
      EMPTY_ARRAY = []

      def initialize(sample_rate: SAMPLE_RATE,
        targets: TARGETS,
        backends_probability: BACKEND_PROBABILITES,
        backends_config: {
          stackprof: StackprofConfig.new,
        },
        paths: nil,
        exclude_targets: EMPTY_ARRAY)

        if sample_rate < 0.0 || sample_rate > 1.0
          raise ArgumentError, "sample_rate must be between 0 and 1"
        end

        raise ArgumentError, "mode probabilities must sum to 1" unless backends_probability.values.sum == 1.0

        ActiveSupport::Deprecation.new.warn("passing paths is deprecated, use targets instead") if paths

        @sample_rate = sample_rate
        @targets = paths || targets
        @backends_config = backends_config
        @backends_probability = backends_probability
        @exclude_targets = exclude_targets
      end

      def get_backend_config(backend_name)
        @backends_config[backend_name]
      end
    end
  end
end
