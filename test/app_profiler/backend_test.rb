# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class BackendTest < TestCase
    test ".backend= fails to update the backend if already profiling" do
      skip("Vernier not supported") unless AppProfiler.vernier_supported?
      assert(AppProfiler.backend = AppProfiler::Backend::StackprofBackend.name)
      AppProfiler.start
      assert(AppProfiler.running?)
      assert_raises(BackendError) { AppProfiler.backend = AppProfiler::Backend::VernierBackend.name }
    ensure
      AppProfiler.stop
    end

    test ".backend= updates the backend if not already profiling" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless AppProfiler.vernier_supported?
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::StackprofBackend.name)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::StackprofBackend.name)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::VernierBackend.name)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::VernierBackend.name)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".backend= accepts a symbol with the backend name" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless AppProfiler.vernier_supported?
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = :stackprof)
      assert_equal(AppProfiler.backend, :stackprof)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = :vernier)
      assert_equal(AppProfiler.backend, :vernier)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".backend_for= provides the backend class given a string" do
      assert_equal(AppProfiler::Backend::StackprofBackend,
        AppProfiler.backend_for(AppProfiler::Backend::StackprofBackend.name))
      return unless AppProfiler.vernier_supported?

      assert_equal(AppProfiler::Backend::VernierBackend,
        AppProfiler.backend_for(AppProfiler::Backend::VernierBackend.name))
    end

    test ".backend_for= raises if an unknown backend is requested" do
      assert_raises(BackendError) { AppProfiler.backend_for("not a real backend") }
    end

    test ".clear stops the backend before discarding its reference to it" do
      profiler = AppProfiler.profiler
      refute(profiler.running?)
      AppProfiler.start
      AppProfiler.send(:clear)
      refute(profiler.running?)
    end
  end
end
