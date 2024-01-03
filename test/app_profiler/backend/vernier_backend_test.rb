# frozen_string_literal: true

require "test_helper"

return unless defined?(AppProfiler::VernierBackend)

module AppProfiler
  class VernierBackendTest < TestCase
    def setup
      AppProfiler.clear
      @orig_backend = AppProfiler.profiler_backend
      AppProfiler.profiler_backend = AppProfiler::VernierBackend
    end

    def teardown
      AppProfiler.profiler_backend = @orig_backend
      AppProfiler.clear
    end

    test ".run prints error when failed" do
      AppProfiler.logger.expects(:info).with { |value| value =~ /failed to start the profiler/ }
      profile = AppProfiler.profiler.run(mode: :unsupported) do
        sleep(0.1)
      end

      assert_nil(profile)
    end

    test ".run raises when yield raises" do
      error = StandardError.new("An error occurred.")
      exception = assert_raises(StandardError) do
        AppProfiler.profiler.run(vernier_profile) do
          assert_predicate(AppProfiler.profiler, :running?)
          raise error
        end
      end

      assert_equal(error, exception)
      assert_not_predicate(AppProfiler.profiler, :running?)
    end

    test ".run does not stop the profiler when it is already running" do
      AppProfiler.logger.expects(:info).never

      assert_equal(true, AppProfiler.profiler.send(:start, vernier_profile))

      profile = AppProfiler.profiler.run(vernier_profile) do
        sleep(0.1)
      end

      assert_nil(profile)
      assert_predicate(AppProfiler.profiler, :running?)
    ensure
      AppProfiler.profiler.stop
    end

    test ".run uses wall profile by default" do
      profile = AppProfiler.profiler.run do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(1000, profile[:interval]) # TODO https://github.com/jhawthorn/vernier/issues/30
    end

    test ".run assigns metadata to profiles" do
      profile = AppProfiler.profiler.run(vernier_profile(metadata: { id: "wowza", context: "bar" })) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal("wowza", profile.id)
      assert_equal("bar", profile.context)
    end

    test ".run cpu profile" do
      skip "on-CPU mode not yet supported by vernier" # https://github.com/jhawthorn/vernier/issues/29
      profile = AppProfiler.profiler.run(vernier_profile(mode: :cpu, interval: 2000)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:cpu, profile[:mode])
      assert_equal(2000, profile[:interval])
    end

    test ".run wall profile" do
      profile = AppProfiler.profiler.run(vernier_profile(mode: :wall, interval: 2000)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(2000, profile[:interval]) # TODO as above
    end

    test ".run object profile" do
      skip "object allocation mode not yet supported by vernier"
      profile = AppProfiler.profiler.run(stackprof_profile(mode: :object, interval: 2)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:object, profile[:mode])
      assert_equal(2, profile[:interval])
    end

    test ".start uses wall profile by default" do
      AppProfiler.profiler.start
      AppProfiler.profiler.stop

      profile = AppProfiler.profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(1000, profile[:interval])
    end

    test ".start assigns metadata to profiles" do
      AppProfiler.profiler.start(vernier_profile(metadata: { id: "wowza", context: "bar" }))
      AppProfiler.profiler.stop

      profile = AppProfiler.profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal("wowza", profile.id)
      assert_equal("bar", profile.context)
    end

    test ".start cpu profile" do
      skip "on-CPU mode not yet supported by vernier" # https://github.com/jhawthorn/vernier/issues/29
      AppProfiler.profiler.start(stackprof_profile(mode: :cpu, interval: 2000))
      AppProfiler.profiler.stop

      profile = AppProfiler.profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:cpu, profile[:mode])
      assert_equal(2000, profile[:interval])
    end

    test ".start wall profile" do
      AppProfiler.profiler.start(vernier_profile(mode: :wall, interval: 2000))
      AppProfiler.profiler.stop

      profile = AppProfiler.profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(2000, profile[:interval])
    end

    test ".start object profile" do
      skip "object allocation mode not yet supported by vernier"
      AppProfiler.profiler.start(vernier_profile(mode: :object, interval: 2))
      AppProfiler.profiler.stop

      profile = AppProfiler.profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:object, profile[:mode])
      assert_equal(2, profile[:interval])
    end

    # test ".stop" do
    #  AppProfiler.start
    #  Vernier::Collector.any_instance.expects(:stop)
    #  AppProfiler.stop
    # end

    test ".results prints error when failed" do
      AppProfiler.profiler.expects(:backend_results).returns({})
      AppProfiler.logger.expects(:info).with { |value| value =~ /failed to obtain the profile/ }

      assert_nil(AppProfiler.profiler.results)
    end

    test ".results returns nil when profiling is still active" do
      AppProfiler.profiler.run do
        assert_nil(AppProfiler.profiler.results)
      end
    end

    test ".start, .stop, and .results interact well" do
      AppProfiler.logger.expects(:info).never

      assert_equal(true, AppProfiler.profiler.start)
      assert_equal(false, AppProfiler.profiler.start)
      assert_equal(true, AppProfiler.profiler.send(:running?))
      assert_nil(AppProfiler.profiler.results)
      assert_equal(true, AppProfiler.profiler.stop)
      assert_equal(false, AppProfiler.profiler.stop)
      assert_equal(false, AppProfiler.profiler.send(:running?))

      profile = AppProfiler.profiler.results
      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_predicate(profile, :valid?)

      assert_nil(AppProfiler.profiler.results)
    end
  end
end
