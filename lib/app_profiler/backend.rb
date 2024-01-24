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
  begin
    autoload(:VernierBackend, "app_profiler/backend/vernier")
  rescue LoadError
    warn("Vernier is not supported.")
  end
  DefaultBackend = AppProfiler::StackprofBackend
end
