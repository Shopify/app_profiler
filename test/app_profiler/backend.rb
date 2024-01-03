# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class BackendTest < TestCase
    test ".profiler does not permit multiple backends" do
      AppProfiler.profiler_backend = AppProfiler::StackprofBackend
      assert_instance_of(StackprofBackend, AppProfiler.profiler)

      AppProfiler.profiler_backend = AppProfiler::VernierBackend
      assert_instance_of(StackprofBackend, AppProfiler.profiler)

      AppProfiler.clear

      AppProfiler.profiler_backend = AppProfiler::VernierBackend
      assert_instance_of(VernierBackend, AppProfiler.profiler)
    end
  end
end
