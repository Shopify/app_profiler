# frozen_string_literal: true

begin
  gem("vernier", ">= 0.3.1")
  require "vernier"
rescue LoadError
  warn("Vernier profiling support requires the vernier gem, version 0.3.1 or later." \
    "Please add it to your Gemfile: `gem \"vernier\", \">= 0.3.1\"`")
  raise
end

module AppProfiler
  class VernierBackend < Backend
    NAME = "vernier"

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
      # This is a boolean instead of nil to be consistent with the stackprof backend behaviour
      # boolean as well.
      false
    end

    def stop
      return false unless running?

      @results = @collector&.stop
      @collector = nil
      !@results.nil?
    end

    def results
      vernier_profile = backend_results
      clear

      return unless vernier_profile

      vernier_profile.meta[:mode] = @mode # TODO: https://github.com/jhawthorn/vernier/issues/30
      vernier_profile.meta.merge!(@metadata) if @metadata
      @mode = nil
      @metadata = nil

      AppProfiler::Profile.from_vernier(vernier_profile)
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
