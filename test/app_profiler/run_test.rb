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

    test ".backend= fails to update the backend if already profiling" do
      skip("Vernier not supported") unless defined?(AppProfiler::VernierBackend)
      assert(AppProfiler.backend = AppProfiler::StackprofBackend)
      AppProfiler.start
      assert(AppProfiler.running?)
      assert_raises(ArgumentError) { AppProfiler.backend = AppProfiler::VernierBackend }
    ensure
      AppProfiler.stop
    end

    test ".backend= updates the backend if not already profiling" do
      orig_backend = AppProfiler.profiler_backend
      skip("Vernier not supported") unless defined?(AppProfiler::VernierBackend)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::StackprofBackend)
      assert_equal(AppProfiler.profiler_backend, AppProfiler::StackprofBackend)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::VernierBackend)
      assert_equal(AppProfiler.profiler_backend, AppProfiler::VernierBackend)
    ensure
      AppProfiler.backend = orig_backend
    end
  end
end
