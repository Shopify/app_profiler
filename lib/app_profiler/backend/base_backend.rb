# frozen_string_literal: true

module AppProfiler
  module Backend
    class BaseBackend
      def run(params = {})
        started = start(params)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        yield

        return unless started

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        stop
        results_data = results

        if results_data
          results_data.metadata[:duration] = duration
        end

        results_data
      ensure
        # Only stop the profiler if profiling was started in this context.
        stop if started
      end

      def start(params = {})
        raise NotImplementedError
      end

      def stop
        raise NotImplementedError
      end

      def results
        raise NotImplementedError
      end

      def running?
        raise NotImplementedError
      end

      class << self
        def run_lock
          @run_lock ||= Mutex.new
        end

        def name
          raise NotImplementedError
        end
      end

      protected

      def acquire_run_lock
        self.class.run_lock.try_lock
      end

      def release_run_lock
        self.class.run_lock.unlock if self.class.run_lock.locked?
      rescue ThreadError
        AppProfiler.logger.warn("[AppProfiler] run lock not released as it was never acquired")
      end
    end
  end
end
