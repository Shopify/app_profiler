# frozen_string_literal: true

require "app_profiler/sampler/stackprof_config"
require "app_profiler/sampler/vernier_config"
module AppProfiler
  module Sampler
    class Config
      attr_reader :sample_rate, :paths, :cpu_interval, :backends_probability

      SAMPLE_RATE = 0.001 # 0.1%
      PATHS = ["/"]
      BACKEND_PROBABILITES = { stackprof: 1.0, vernier: 0.0 }
      @backends = {}

      def initialize(sample_rate: SAMPLE_RATE,
        paths: PATHS,
        backends_probability: BACKEND_PROBABILITES,
        backends_config: {
          stackprof: StackprofConfig.new,
        })

        if sample_rate < 0.0 || sample_rate > 1.0
          raise ArgumentError, "sample_rate must be between 0 and 1"
        end

        raise ArgumentError, "mode probabilities must sum to 1" unless backends_probability.values.sum == 1.0

        @sample_rate = sample_rate
        @paths = paths
        @backends_config = backends_config
        @backends_probability = backends_probability
      end

      def get_backend_config(backend_name)
        @backends_config[backend_name]
      end
    end
  end
end
