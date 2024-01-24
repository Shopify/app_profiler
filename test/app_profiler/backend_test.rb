# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class BackendTest < TestCase
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
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless defined?(AppProfiler::VernierBackend)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::StackprofBackend)
      assert_equal(AppProfiler.backend, AppProfiler::StackprofBackend)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::VernierBackend)
      assert_equal(AppProfiler.backend, AppProfiler::VernierBackend)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".with_backend sets the backend then returns to the previous value" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless defined?(AppProfiler::VernierBackend)

      assert_equal(AppProfiler.backend, AppProfiler::StackprofBackend)
      refute(AppProfiler.running?)
      AppProfiler.with_backend(AppProfiler::VernierBackend::NAME) do
        assert_equal(AppProfiler::VernierBackend, AppProfiler.backend)
      end
      assert_equal(AppProfiler.backend, AppProfiler::StackprofBackend)
    ensure
      AppProfiler.backend = orig_backend
    end
  end
end
