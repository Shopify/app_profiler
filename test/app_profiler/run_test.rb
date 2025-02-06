# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class RunTest < TestCase
    test ".run delegates to profiler.run" do
      AppProfiler.profiler.expects(:run)

      AppProfiler.run do
        sleep 0.1
      end
    end

    test ".start delegates to profiler.start" do
      AppProfiler.profiler.expects(:start)

      AppProfiler.start
    end

    test ".stop stops profiler and gets results" do
      AppProfiler.start
      sleep 0.1
      profile = AppProfiler.stop

      assert_instance_of(StackprofProfile, profile)
    end

    test ".run sets the backend then returns to the previous value" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless AppProfiler.vernier_supported?

      assert_equal(AppProfiler::Backend::StackprofBackend.name, AppProfiler.backend)
      refute(AppProfiler.running?)
      AppProfiler.run(backend: AppProfiler::VernierProfile::BACKEND_NAME) do
        assert_equal(AppProfiler::VernierProfile::BACKEND_NAME, AppProfiler.backend)
      end
      assert_equal(AppProfiler.backend, AppProfiler::Backend::StackprofBackend.name)
    ensure
      AppProfiler.backend = orig_backend
    end
  end
end
