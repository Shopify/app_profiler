# frozen_string_literal: true

module AppProfiler
  module Sampler
    class << self
      def profile_params(request, config)
        return unless sample?(config, request)

        random = Kernel.rand
        backend = if random <= config.stackprof_probability
          :stackprof
        else
          :vernier
        end

        mode = if random <= config.wall_mode_probability
          :wall
        elsif backend == :vernier
          :retained
        else
          :object
        end

        AppProfiler::Parameters.new(
          mode: mode,
          interval: config.send("#{mode}_interval"),
          async: true,
          backend: backend,
        )
      end

      private

      def sample?(config, request)
        return false if rand > config.sample_rate

        path = request.path
        return false unless config.paths.any? { |p| path.match?(p) }

        true
      end
    end

    class Config
      attr_reader :sample_rate,
        :paths,
        :cpu_interval,
        :wall_interval,
        :object_interval,
        :retained_interval,
        :wall_mode_probability,
        :object_or_retained_mode_probability,
        :stackprof_probability,
        :vernier_probability

      ## Default values
      SAMPLE_RATE = 0.001 # 0.1%
      PATHS = ["/"]

      WALL_INTERVAL = 5000
      OBJECT_INTERVAL = 1000

      WALL_MODE_PROBABILITY = 0.8 # 80.0%
      OBJECT_OR_RETAINED_MODE_PROBABILITY = 0.2 # 20.0%

      STACKPROF_PROBABILITY = 1.0 # 100.0%
      VERNIER_PROBABILITY = 0.0 # 0.0%

      def initialize(
        sample_rate: SAMPLE_RATE,
        paths: PATHS,
        wall_interval: WALL_INTERVAL,
        object_interval: OBJECT_INTERVAL,
        retained_interval: RETAINED_INTERVAL,
        wall_mode_probability: WALL_MODE_PROBABILITY,
        object_or_retained_mode_probability: OBJECT_OR_RETAINED_MODE_PROBABILITY,
        stackprof_probability: STACKPROF_PROBABILITY,
        vernier_probability: VERNIER_PROBABILITY
      )
        @sample_rate = sample_rate
        @paths = paths
        @wall_interval = wall_interval
        @object_interval = object_interval
        @retained_interval = retained_interval
        @wall_mode_probability = wall_mode_probability
        @object_or_retained_mode_probability = object_mode_probability
        @stackprof_probability = stackprof_probability
        @vernier_probability = vernier_probability
      end
    end
  end
end
