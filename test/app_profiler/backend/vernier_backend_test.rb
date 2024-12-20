# frozen_string_literal: true

require "test_helper"

return unless AppProfiler.vernier_supported?

module AppProfiler
  module Backend
    class VernierBackendTest < TestCase
      def setup
        @original_backend = AppProfiler.backend
        AppProfiler.backend = :vernier
      end

      def teardown
        AppProfiler.backend = @original_backend
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
          AppProfiler.profiler.run(vernier_params) do
            assert_predicate(AppProfiler.profiler, :running?)
            raise error
          end
        end

        assert_equal(error, exception)
        assert_not_predicate(AppProfiler.profiler, :running?)
      end

      test ".run does not stop the profiler when it is already running" do
        AppProfiler.logger.expects(:info).never

        assert_equal(true, AppProfiler.profiler.send(:start, vernier_params))

        profile = AppProfiler.profiler.run(vernier_params) do
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
        assert_equal(:wall, profile[:meta][:mode])
        assert_equal(1, profile[:meta][:interval])
      end

      test ".run assigns metadata to profiles" do
        profile = AppProfiler.profiler.run(
          vernier_params(metadata: {
            id: "wowza",
            context: "bar",
            extrameta: "spam",
          }),
        ) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::VernierProfile, profile)
        assert_equal("wowza", profile.id)
        assert_equal("bar", profile.context)
        assert_equal("spam", profile[:meta][:extrameta])
      end

      test ".run wall profile" do
        profile = AppProfiler.profiler.run(vernier_params(mode: :wall, interval: 2000)) do
          sleep(0.1)
        end

        assert_instance_of(AppProfiler::VernierProfile, profile)
        assert_equal(:wall, profile[:meta][:mode])
        # assert_equal(2000, profile[:interval]) # TODO as above
      end

      test ".run retained profile" do
        retained = []
        objects = 10
        profile = AppProfiler.profiler.run(vernier_params(mode: :retained)) do
          objects.times do
            retained << Object.new
          end
        end

        assert_instance_of(AppProfiler::VernierProfile, profile)
        assert_equal(:retained, profile[:meta][:mode])

        num_samples = profile[:threads].flat_map { _1[:samples] }.sum { |s| s[:length] }
        assert_operator(num_samples, :>=, objects)
      end

      test ".run works for supported modes" do
        profile = AppProfiler.profiler.run(vernier_params(mode: :wall)) do
          sleep(0.1)
        end
        refute_equal(false, profile)

        profile = AppProfiler.profiler.run(vernier_params(mode: :retained)) do
          sleep(0.1)
        end
        refute_equal(false, profile)
      end

      test ".run fails for unsupported modes" do
        unsupported_modes = [:cpu, :object, :garbage, :unsupported]

        unsupported_modes.each do |unsupported|
          profile = AppProfiler.profiler.run(vernier_params(mode: unsupported)) do
            sleep(0.1)
          end
          assert_nil(profile)
        end
      end

      test ".start uses wall profile by default" do
        AppProfiler.profiler.start
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::VernierProfile, profile)
        assert_equal(:wall, profile[:meta][:mode])
        # assert_equal(1000, profile[:interval])
      end

      test ".start assigns metadata to profiles" do
        AppProfiler.profiler.start(vernier_params(metadata: { id: "wowza", context: "bar" }))
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::VernierProfile, profile)
        assert_equal("wowza", profile.id)
        assert_equal("bar", profile.context)
      end

      test ".start wall profile" do
        AppProfiler.profiler.start(vernier_params(mode: :wall, interval: 2000))
        AppProfiler.profiler.stop

        profile = AppProfiler.profiler.results

        assert_instance_of(AppProfiler::VernierProfile, profile)
        assert_equal(:wall, profile[:meta][:mode])
        # assert_equal(2000, profile[:interval])
      end

      test ".stop" do
        Vernier::Collector.any_instance.expects(:start)
        Vernier::Collector.any_instance.expects(:stop)

        AppProfiler.profiler.start
        AppProfiler.profiler.stop
      end

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
end
