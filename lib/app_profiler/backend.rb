# frozen_string_literal: true

module AppProfiler
  class Backend
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
  end
end

require "app_profiler/backend/stackprof"

begin
  require "app_profiler/backend/vernier"
rescue LoadError
  warn("Vernier is not supported.")
end
