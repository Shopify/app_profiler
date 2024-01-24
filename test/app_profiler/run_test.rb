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
  end
end
