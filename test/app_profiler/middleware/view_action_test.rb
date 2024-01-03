# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class Middleware
    class ViewActionTest < AppProfiler::TestCase
      setup do
        @profile = Profile.new(stackprof_profile)
        @response = [200, {}, ["OK"]]
      end

      test ".cleanup" do
        AppProfiler.profiler.expects(:results).returns(@profile)
        @profile.expects(:view)

        ViewAction.cleanup
      end

      test ".call views profile" do
        @profile.expects(:view)

        ViewAction.call(@profile, response: @response)
      end
    end
  end
end
