# frozen_string_literal: true

module AppProfiler
  module Backend
    autoload :BaseBackend, "app_profiler/backend/base_backend"
    autoload :StackprofBackend, "app_profiler/backend/stackprof_backend"
    autoload :VernierBackend, "app_profiler/backend/vernier_backend"
  end
end
