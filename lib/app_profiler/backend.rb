# frozen_string_literal: true

module AppProfiler
  module Backend
    class Base
      def run(params = {}, &block)
        raise NotImplementedError
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
      end

      protected

      def acquire_run_lock
        self.class.run_lock.try_lock
      end

      def release_run_lock
        self.class.run_lock.unlock
      rescue ThreadError
        AppProfiler.logger.warn("[AppProfiler] run lock not released as it was never acquired")
      end
    end
  end
end
