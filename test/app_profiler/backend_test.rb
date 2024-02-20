# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class BackendTest < TestCase
    test ".backend= fails to update the backend if already profiling" do
      skip("Vernier not supported") unless defined?(AppProfiler::Backend::Vernier::NAME)
      assert(AppProfiler.backend = AppProfiler::Backend::Stackprof)
      AppProfiler.start
      assert(AppProfiler.running?)
      assert_raises(BackendError) { AppProfiler.backend = AppProfiler::Backend::Vernier }
    ensure
      AppProfiler.stop
    end

    test ".backend= updates the backend if not already profiling" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless defined?(AppProfiler::Backend::Vernier::NAME)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::Stackprof)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::Stackprof)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::Vernier)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::Vernier)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".backend= accepts a string with the backend name" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless defined?(AppProfiler::Backend::Vernier::NAME)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::Stackprof::NAME)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::Stackprof)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::Vernier::NAME)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::Vernier)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".backend= accepts a backend class" do
      orig_backend = AppProfiler.backend
      skip("Vernier not supported") unless defined?(AppProfiler::Backend::Vernier::NAME)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::Stackprof)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::Stackprof)
      refute(AppProfiler.running?)
      assert(AppProfiler.backend = AppProfiler::Backend::Vernier)
      assert_equal(AppProfiler.backend, AppProfiler::Backend::Vernier)
    ensure
      AppProfiler.backend = orig_backend
    end

    test ".backend_for= provides the backend class given a string" do
      assert_equal(AppProfiler::Backend::Stackprof, AppProfiler.backend_for(AppProfiler::Backend::Stackprof::NAME))
      return unless defined?(AppProfiler::Backend::Vernier::NAME)

      assert_equal(AppProfiler::Backend::Vernier, AppProfiler.backend_for(AppProfiler::Backend::Vernier::NAME))
    end

    test ".backend_for= raises if an unknown backend is requested" do
      assert_raises(BackendError) { AppProfiler.backend_for("not a real backend") }
    end
  end
end
