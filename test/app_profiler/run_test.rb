# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class RunTest < TestCase
    test ".run delegates to Profiler.run" do
      profile = AppProfiler.run(stackprof_profile(mode: :cpu, interval: 2000)) do
        sleep(0.1)
      end

      assert_instance_of(AppProfiler::Profile, profile)
    end
  end
end
