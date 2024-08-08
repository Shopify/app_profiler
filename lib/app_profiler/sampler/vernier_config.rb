# frozen_string_literal: true

module AppProfiler
  module Sampler
    class VernierConfig
      attr_reader :modes_probability

      WALL_INTERVAL = 5000
      RETAINED_INTERVAL = 5000

      WALL_MODE_PROBABILITY = 1.0
      RETAINED_MODE_PROBABILITY = 0.0

      def initialize(
        wall_interval: WALL_INTERVAL,
        retained_interval: RETAINED_INTERVAL,
        wall_mode_probability: WALL_MODE_PROBABILITY,
        retained_mode_probability: RETAINED_MODE_PROBABILITY
      )
        if wall_mode_probability + retained_mode_probability != 1.0
          raise ArgumentError, "mode probabilities must sum to 1"
        end

        @modes_probability = {}
        @modes_interval = {}

        AppProfiler::Backend::VernierBackend::AVAILABLE_MODES.each do |mode|
          case mode
          when :wall
            @modes_probability[mode] = wall_mode_probability
            @modes_interval[mode] = wall_interval
          when :retained
            @modes_probability[mode] = retained_mode_probability
            @modes_interval[mode] = retained_interval
          end
        end
      end

      def interval_for(mode)
        @modes_interval[mode]
      end
    end
  end
end
