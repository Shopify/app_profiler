# frozen_string_literal: true

require "vernier"

module AppProfiler
  module Backend
    module Vernier
      DEFAULTS = {
        mode: :wall,
      }.freeze

      class << self
        def run(params = {})
          started = start(params)

          yield

          return unless started

          stop
          results
        ensure
          # Only stop the profiler if profiling was started in this context.
          stop if started
        end

        def start(params = {})
          # Do not start the profiler if we already have a collector started somewhere else.
          return false if running?

          @mode = params.delete(:mode) || DEFAULTS[:mode]
          @metadata = params.delete(:metadata)
          clear

          @collector ||= ::Vernier::Collector.new(@mode, **params)
          @collector.start
        rescue => error
          AppProfiler.logger.info(
            "[Profiler] failed to start the profiler error_class=#{error.class} error_message=#{error.message}"
          )
          # This is a boolean instead of nil to be consistent with the stackprof backend behaviour
          # boolean as well.
          false
        end

        def stop
          @results = @collector&.stop
          @collector = nil
          @results
        end

        def results
          vernier_profile = backend_results

          return unless vernier_profile

          vernier_profile.meta[:mode] = @mode # TODO: https://github.com/jhawthorn/vernier/issues/30
          vernier_profile.meta.merge!(@metadata) if @metadata
          @mode = nil
          @metadata = nil

          AppProfiler::Profile.from_vernier(vernier_profile)
        rescue => error
          puts "HERE #{error.message}"
          AppProfiler.logger.info(
            "[Profiler] failed to obtain the profile error_class=#{error.class} error_message=#{error.message}"
          )
          nil
        end

        private

        def backend_results
          @results
        end

        def clear
          @results = nil
        end

        def running?
          @collector != nil
        end
      end
    end
  end
end
