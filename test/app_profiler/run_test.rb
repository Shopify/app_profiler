# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class RunTest < TestCase
    test ".run delegates to AppProfiler.run" do
      AppProfiler.expects(:run)

      AppProfiler.run do
        sleep 0.1
      end
    end

    test ".start delegates to AppProfiler.start" do
      AppProfiler.expects(:start)

      AppProfiler.start
    end

    test ".stop stops profiler and gets results" do
      AppProfiler.start
      AppProfiler.stop
      sleep 0.1
      profile = AppProfiler.results

      assert_instance_of(StackprofProfile, profile)
    end
  end
end
