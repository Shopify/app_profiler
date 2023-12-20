# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class VernierBackendTest < TestCase
    def setup
      @orig_backend = AppProfiler.profiler_backend
      AppProfiler.profiler_backend = AppProfiler::Backend::Vernier
    end

    test ".run prints error when failed" do
      AppProfiler.logger.expects(:info).with { |value| value =~ /failed to start the profiler/ }
      profile = Profiler.run(mode: :unsupported) do
        sleep(0.1)
      end

      assert_nil(profile)
    end

    test ".run raises when yield raises" do
      error = StandardError.new("An error occurred.")
      exception = assert_raises(StandardError) do
        Profiler.run(vernier_profile) do
          assert_predicate(Profiler, :running?)
          raise error
        end
      end

      assert_equal(error, exception)
      assert_not_predicate(Profiler, :running?)
    end

    test ".run does not stop the profiler when it is already running" do
      AppProfiler.logger.expects(:info).never

      assert_equal(true, Profiler.send(:start, vernier_profile))

      profile = Profiler.run(vernier_profile) do
        sleep(0.1)
      end

      assert_nil(profile)
      assert_predicate(Profiler, :running?)
    ensure
      Profiler.stop
    end

    test ".run uses wall profile by default" do
      profile = Profiler.run do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(1000, profile[:interval]) # TODO https://github.com/jhawthorn/vernier/issues/30
    end

    test ".run assigns metadata to profiles" do
      profile = Profiler.run(vernier_profile(metadata: { id: "wowza", context: "bar" })) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal("wowza", profile.id)
      assert_equal("bar", profile.context)
    end

    test ".run cpu profile" do
      skip "on-CPU mode not yet supported by vernier" # https://github.com/jhawthorn/vernier/issues/29
      profile = Profiler.run(vernier_profile(mode: :cpu, interval: 2000)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:cpu, profile[:mode])
      assert_equal(2000, profile[:interval])
    end

    test ".run wall profile" do
      profile = Profiler.run(vernier_profile(mode: :wall, interval: 2000)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(2000, profile[:interval]) # TODO as above
    end

    test ".run object profile" do
      skip "object allocation mode not yet supported by vernier"
      profile = Profiler.run(stackprof_profile(mode: :object, interval: 2)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:object, profile[:mode])
      assert_equal(2, profile[:interval])
    end

    test ".start uses wall profile by default" do
      Profiler.start
      Profiler.stop

      profile = Profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(1000, profile[:interval])
    end

    test ".start assigns metadata to profiles" do
      Profiler.start(vernier_profile(metadata: { id: "wowza", context: "bar" }))
      Profiler.stop

      profile = Profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal("wowza", profile.id)
      assert_equal("bar", profile.context)
    end

    test ".start cpu profile" do
      skip "on-CPU mode not yet supported by vernier" # https://github.com/jhawthorn/vernier/issues/29
      Profiler.start(stackprof_profile(mode: :cpu, interval: 2000))
      Profiler.stop

      profile = Profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:cpu, profile[:mode])
      assert_equal(2000, profile[:interval])
    end

    test ".start wall profile" do
      Profiler.start(vernier_profile(mode: :wall, interval: 2000))
      Profiler.stop

      profile = Profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:wall, profile[:mode])
      # assert_equal(2000, profile[:interval])
    end

    test ".start object profile" do
      skip "object allocation mode not yet supported by vernier"
      Profiler.start(vernier_profile(mode: :object, interval: 2))
      Profiler.stop

      profile = Profiler.results

      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_equal(:object, profile[:mode])
      assert_equal(2, profile[:interval])
    end

    #test ".stop" do
    #  AppProfiler.start
    #  Vernier::Collector.any_instance.expects(:stop)
    #  AppProfiler.stop
    #end

    test ".results prints error when failed" do
      AppProfiler.profiler_backend.expects(:backend_results).returns({})
      AppProfiler.logger.expects(:info).with { |value| value =~ /failed to obtain the profile/ }

      assert_nil(Profiler.results)
    end

    test ".results returns nil when profiling is still active" do
      Profiler.run do
        assert_nil(Profiler.results)
      end
    end

    test ".start, .stop, and .results interact well" do
      AppProfiler.logger.expects(:info).never

      assert_equal(true, Profiler.start)
      assert_equal(false, Profiler.start)
      assert_equal(true, Profiler.send(:running?))
      assert_nil(Profiler.results)
      assert_equal(true, Profiler.stop)
      assert_equal(false, Profiler.stop)
      assert_equal(false, Profiler.send(:running?))

      profile = Profiler.results
      assert_instance_of(AppProfiler::VernierProfile, profile)
      assert_predicate(profile, :valid?)

      assert_nil(Profiler.results)
    end

    def teardown
      AppProfiler.profiler_backend = @orig_backend
      @orig_backend = nil
    end
  end
end
