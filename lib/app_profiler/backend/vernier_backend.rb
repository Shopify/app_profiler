# frozen_string_literal: true

gem("vernier", ">= 0.4.0")
require "vernier"

module AppProfiler
  module Backend
    class VernierBackend < Base
      NAME = :vernier

      DEFAULTS = {
        mode: :wall,
      }.freeze

      AVAILABLE_MODES = [
        :wall,
        :retained,
      ].freeze

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
        return false unless acquire_run_lock

        @mode = params.delete(:mode) || DEFAULTS[:mode]
        raise ArgumentError unless AVAILABLE_MODES.include?(@mode)

        @metadata = params.delete(:metadata)
        clear

        @collector ||= ::Vernier::Collector.new(@mode, **params)
        @collector.start
      rescue => error
        AppProfiler.logger.info(
          "[Profiler] failed to start the profiler error_class=#{error.class} error_message=#{error.message}"
        )
        release_run_lock
        # This is a boolean instead of nil to be consistent with the stackprof backend behaviour
        # boolean as well.
        false
      end

      def stop
        return false unless running?

        @results = @collector&.stop
        @collector = nil
        !@results.nil?
      ensure
        release_run_lock
      end

      def results
        vernier_profile = backend_results
        clear

        return unless vernier_profile

        # HACK: - "data" is private, but we want to avoid serializing to JSON then
        # parsing back from JSON by just directly getting the hash
        data = ::Vernier::Output::Firefox.new(vernier_profile).send(:data)
        data[:meta][:mode] = @mode # TODO: https://github.com/jhawthorn/vernier/issues/30
        data[:meta].merge!(@metadata) if @metadata
        @mode = nil
        @metadata = nil

        AppProfiler::AbstractProfile.from_vernier(data)
      rescue => error
        AppProfiler.logger.info(
          "[Profiler] failed to obtain the profile error_class=#{error.class} error_message=#{error.message}"
        )
        nil
      end

      def running?
        @collector != nil
      end

      private

      def backend_results
        @results
      end

      def clear
        @results = nil
      end
    end
  end
end
