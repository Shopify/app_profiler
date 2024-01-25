# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class BackendTest < TestCase
    test ".backend= fails to update the backend if already profiling" do
      skip("Vernier not supported") unless defined?(AppProfiler::VernierBackend)
      assert(AppProfiler.backend = AppProfiler::StackprofBackend)
      AppProfiler.start
      assert(AppProfiler.running?)
      assert_raises(BackendError) { AppProfiler.backend = AppProfiler::VernierBackend }
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

    test ".backend= accepts a string with the backend name" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless defined?(AppProfiler::VernierBackend)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::StackprofBackend::NAME)
      assert_equal(AppProfiler.backend, AppProfiler::StackprofBackend)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::VernierBackend::NAME)
      assert_equal(AppProfiler.backend, AppProfiler::VernierBackend)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".backend= accepts a backend class" do
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

    test ".backend_for= provides the backend class given a string" do
      assert_equal(AppProfiler::StackprofBackend, AppProfiler.backend_for(AppProfiler::StackprofBackend::NAME))
      return unless defined?(AppProfiler::VernierBackend)

      assert_equal(AppProfiler::VernierBackend, AppProfiler.backend_for(AppProfiler::VernierBackend::NAME))
    end

    test ".backend_for= raises if an unknown backend is requested" do
      assert_raises(BackendError) { AppProfiler.backend_for("not a real backend") }
    end
  end
end
