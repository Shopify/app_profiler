# frozen_string_literal: true

require "stackprof"

module AppProfiler
  class StackprofBackend < Backend
    NAME = "stackprof"
    DEFAULTS = {
      mode: :cpu,
      raw: true,
    }.freeze

    AVAILABLE_MODES = [
      :wall,
      :cpu,
      :object,
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
      # Do not start the profiler if StackProf was started somewhere else.
      return false if running?

      clear

      ::StackProf.start(**DEFAULTS, **params)
    rescue => error
      AppProfiler.logger.info(
        "[Profiler] failed to start the profiler error_class=#{error.class} error_message=#{error.message}"
      )
      # This is a boolean instead of nil because StackProf#start returns a
      # boolean as well.
      false
    end

    def stop
      ::StackProf.stop
    end

    def results
      stackprof_profile = backend_results

      return unless stackprof_profile

      AppProfiler::Profile.from_stackprof(stackprof_profile)
    rescue => error
      AppProfiler.logger.info(
        "[Profiler] failed to obtain the profile error_class=#{error.class} error_message=#{error.message}"
      )
      nil
    end

    def running?
      ::StackProf.running?
    end

    private

    def backend_results
      ::StackProf.results
    end

    # Clears the previous profiling session.
    #
    # StackProf will attempt to reuse frames from the previous profiling
    # session if the results are not collected. This is usually called before
    # StackProf#start is invoked to ensure that new profiling sessions do
    # not reuse previous frames if they exist.
    #
    # Ref: https://github.com/tmm1/stackprof/blob/0ded6c/ext/stackprof/stackprof.c#L118-L123
    #
    def clear
      backend_results
    end
  end
end
