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

  autoload :StackprofBackend, "app_profiler/backend/stackprof"
  autoload :VernierBackend, "app_profiler/backend/vernier"
  DefaultBackend = AppProfiler::StackprofBackend
end
