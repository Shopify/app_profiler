# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Backend
    class StackprofBackendTest < TestCase
      def setup
        @original_backend = AppProfiler.backend
        AppProfiler.backend = :stackprof
      end

      def teardown
        AppProfiler.backend = @original_backend
      end

      test ".run prints error when failed" do
        AppProfiler.logger.expects(:info).with { |value| value =~ /failed to start the profiler/ }
        profile = AppProfiler.run(mode: :unsupported) do
          sleep(0.1)
        end

        assert_nil(profile)
      end

      test ".run raises when yield raises" do
        error = StandardError.new("An error occurred.")
        exception = assert_raises(StandardError) do
          AppProfiler.profiler.run(stackprof_profile) do
            assert_predicate(AppProfiler.profiler, :running?)
            raise error
          end
        end

        assert_equal(error, exception)
        assert_not_predicate(AppProfiler.profiler, :running?)
      end

      test ".run does not stop the profiler when it is already running" do
        AppProfiler.logger.expects(:info).never

        assert_equal(true, AppProfiler.profiler.send(:start, stackprof_profile))

        profile = AppProfiler.profiler.run(stackprof_profile) do
          sleep(0.1)
        end

        assert_nil(profile)
        assert_predicate(AppProfiler.profiler, :running?)
      ensure
        AppProfiler.profiler.stop
      end

      test ".run uses cpu profile by default" do
        profile = AppProfiler.profiler.run(stackprof_profile) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:cpu, profile[:mode])
        assert_equal(1000, profile[:interval])
      end

      test ".run stops its capture only once" do
        stop = StackProf.method(:stop)
        StackProf.expects(:stop).once.with do
          stop.call
          true
        end

        AppProfiler.profiler.run(stackprof_profile) { :completed }
      end

      test ".run releases the lock when result collection raises" do
        backend = StackprofBackend.new
        backend.expects(:results).raises(RuntimeError, "collection failed")

        error = assert_raises(RuntimeError) { backend.run(stackprof_profile) { :completed } }

        assert_equal("collection failed", error.message)
        refute_predicate(StackprofBackend, :locked?)
        refute_predicate(backend, :running?)
      ensure
        StackProf.results
      end

      test ".run honors backend stop overrides" do
        backend = StackprofBackend.new
        stop = backend.method(:stop)
        backend.expects(:stop).once.with do
          stop.call
          true
        end

        assert_instance_of(StackprofProfile, backend.run(stackprof_profile) { :completed })
      ensure
        StackProf.stop
        StackProf.results
      end

      test ".run keeps the shared lock until results are collected" do
        competitor = StackprofBackend.new
        StackProf.expects(:results).twice.with do
          assert_predicate(StackprofBackend, :locked?)
          true
        end.returns(nil, stackprof_profile)

        assert_instance_of(StackprofProfile, AppProfiler.profiler.run(stackprof_profile) { :completed })
        StackProf.unstub(:results)
        assert(competitor.start(stackprof_profile))
      ensure
        StackProf.unstub(:results)
        competitor.stop
        competitor.results
      end

      test ".run assigns metadata to profiles" do
        profile = AppProfiler.profiler.run(stackprof_profile(metadata: { id: "wowza", context: "bar" })) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal("wowza", profile.id)
        assert_equal("bar", profile.context)
      end

      test ".run cpu profile" do
        profile = AppProfiler.profiler.run(stackprof_profile(mode: :cpu, interval: 2000)) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:cpu, profile[:mode])
        assert_equal(2000, profile[:interval])
      end

      test ".run wall profile" do
        profile = AppProfiler.profiler.run(stackprof_profile(mode: :wall, interval: 2000)) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:wall, profile[:mode])
        assert_equal(2000, profile[:interval])
      end

      test ".run object profile" do
        profile = AppProfiler.profiler.run(stackprof_profile(mode: :object, interval: 2)) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:object, profile[:mode])
        assert_equal(2, profile[:interval])
      end

      test ".start uses cpu profile by default" do
        AppProfiler.profiler.start(stackprof_profile)
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:cpu, profile[:mode])
        assert_equal(1000, profile[:interval])
      end

      test ".start assigns metadata to profiles" do
        AppProfiler.profiler.start(stackprof_profile(metadata: { id: "wowza", context: "bar" }))
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal("wowza", profile.id)
        assert_equal("bar", profile.context)
      end

      test ".start cpu profile" do
        AppProfiler.profiler.start(stackprof_profile(mode: :cpu, interval: 2000))
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:cpu, profile[:mode])
        assert_equal(2000, profile[:interval])
      end

      test ".start wall profile" do
        AppProfiler.profiler.start(stackprof_profile(mode: :wall, interval: 2000))
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:wall, profile[:mode])
        assert_equal(2000, profile[:interval])
      end

      test ".start object profile" do
        AppProfiler.profiler.start(stackprof_profile(mode: :object, interval: 2))
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_equal(:object, profile[:mode])
        assert_equal(2, profile[:interval])
      end

      test ".stop" do
        StackProf.expects(:stop)
        AppProfiler.stop
      end

      test ".stop discards its cached profiler before a later capture starts" do
        backend = AppProfiler.profiler
        release = backend.method(:release_run_lock)
        replacement = nil
        params = stackprof_profile
        AppProfiler.start(params)
        backend.stubs(:release_run_lock).with do
          release.call
          unless StackprofBackend.locked?
            replacement = AppProfiler.profiler
            refute_same(backend, replacement)
            assert(replacement.start(params))
          end
          true
        end

        assert_instance_of(StackprofProfile, AppProfiler.stop)
        assert_same(replacement, AppProfiler.profiler)
        assert_predicate(replacement, :running?)
      ensure
        replacement&.stop
        replacement&.results
      end

      test ".stop keeps the shared lock until results are collected" do
        AppProfiler.start(stackprof_profile)
        StackProf.expects(:results).once.with do
          assert_predicate(StackprofBackend, :locked?)
          true
        end.returns(stackprof_profile)

        assert_instance_of(StackprofProfile, AppProfiler.stop)
        refute_predicate(StackprofBackend, :locked?)
      ensure
        StackProf.unstub(:results)
        AppProfiler.stop
      end

      test ".results prints error when failed" do
        AppProfiler.profiler.expects(:backend_results).returns({})
        AppProfiler.logger.expects(:info).with { |value| value =~ /failed to obtain the profile/ }

        assert_nil(AppProfiler.profiler.results)
      end

      test ".results returns nil when profiling is still active" do
        AppProfiler.profiler.run(stackprof_profile) do
          assert_nil(AppProfiler.profiler.results)
        end
      end

      test ".start, .stop, and .results interact well" do
        AppProfiler.logger.expects(:info).never

        assert_equal(true, AppProfiler.profiler.start(stackprof_profile))
        assert_equal(false, AppProfiler.profiler.start(stackprof_profile))
        assert_equal(true, AppProfiler.profiler.send(:running?))
        assert_nil(AppProfiler.profiler.results)
        assert_equal(true, AppProfiler.profiler.stop)
        assert_equal(false, AppProfiler.profiler.stop)
        assert_equal(false, AppProfiler.profiler.send(:running?))

        profile = AppProfiler.profiler.results
        assert_instance_of(AppProfiler::StackprofProfile, profile)
        assert_predicate(profile, :valid?)

        assert_nil(AppProfiler.profiler.results)
      end
    end
  end
end
