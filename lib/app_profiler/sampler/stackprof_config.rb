# frozen_string_literal: true

module AppProfiler
  module Sampler
    class StackprofConfig
      attr_reader :modes_probability

      # Default values
      WALL_INTERVAL = 5000
      CPU_INTERVAL = 5000
      OBJECT_INTERVAL = 1000

      WALL_MODE_PROBABILITY = 0.8
      CPU_MODE_PROBABILITY = 0.1
      OBJECT_MODE_PROBABILITY = 0.1

      def initialize(
        wall_interval: WALL_INTERVAL,
        cpu_interval: CPU_INTERVAL,
        object_interval: OBJECT_INTERVAL,
        wall_mode_probability: WALL_MODE_PROBABILITY,
        cpu_mode_probability: CPU_MODE_PROBABILITY,
        object_mode_probability: OBJECT_MODE_PROBABILITY
      )
        if wall_mode_probability + cpu_mode_probability + object_mode_probability != 1.0
          raise ArgumentError, "mode probabilities must sum to 1"
        end

        @modes_probability = {}
        @modes_interval = {}

        AppProfiler::Backend::StackprofBackend::AVAILABLE_MODES.each do |mode|
          case mode
          when :wall
            @modes_probability[mode] = wall_mode_probability
            @modes_interval[mode] = wall_interval
          when :cpu
            @modes_probability[mode] = cpu_mode_probability
            @modes_interval[mode] = cpu_interval
          when :object
            @modes_probability[mode] = object_mode_probability
            @modes_interval[mode] = object_interval
          end
        end
      end

      def interval_for(mode)
        @modes_interval[mode]
      end
    end
  end
end
