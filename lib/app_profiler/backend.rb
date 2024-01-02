# frozen_string_literal: true

module AppProfiler
  module Backend
  end
end

require "app_profiler/backend/stackprof"

begin
  require "app_profiler/backend/vernier"
rescue LoadError
  warn("Vernier is not supported.")
end
