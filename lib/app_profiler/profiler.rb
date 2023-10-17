# frozen_string_literal: true

module AppProfiler
  module Profiler
    class << self
      def run(params = {}, &block)
        AppProfiler.profiler_backend.run(params, &block)
      end

      def start(params = {})
        AppProfiler.profiler_backend.start(params)
      end

      def stop
        AppProfiler.profiler_backend.stop
      end

      def results
        AppProfiler.profiler_backend.results
      end

      private

      def clear
        AppProfiler.profiler_backend.send(:stackprof_results)
      end

      def running?
        AppProfiler.profiler_backend.send(:running?)
      end
    end
  end
  private_constant :Profiler
end
