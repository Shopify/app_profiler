# frozen_string_literal: true

require "app_profiler/sampler/config"

module AppProfiler
  module Sampler
    @excluded_cache = {}
    class << self
      def profile_params(request, config)
        profile_params_for(request.path, config)
      end

      def profile_params_for(target, config)
        return unless sample?(config, target)

        get_profile_params(config)
      end

      private

      def sample?(config, target)
        return false if Kernel.rand > config.sample_rate
        return false if @excluded_cache[target]

        if config.exclude_targets.any? { |t| target.match?(t) }
          @excluded_cache[target] = true
          return false
        end

        return false unless config.targets.any? { |t| target.match?(t) }

        true
      end

      def get_profile_params(config)
        backend_name = select_random(config.backends_probability)
        backend_config = config.get_backend_config(backend_name)

        mode = select_random(backend_config.modes_probability)
        interval = backend_config.interval_for(mode)

        AppProfiler::Parameters.new(
          backend: backend_name,
          mode: mode,
          async: true,
          interval: interval,
        )
      end

      # Given options with probabilities, select one based on range.
      # For example, given options {a: 0.1, b: 0.2, c: 0.7} and random 0.5,
      # it will return :c
      # Assumes all probabilities sum to 1

      def select_random(options)
        random = Kernel.rand
        current = 0
        options = options.sort_by do |_, probability|
          probability
        end

        options.each do |o, probabilty|
          current += probabilty
          if random <= current
            return o
          end
        end
      end
    end
  end
end
