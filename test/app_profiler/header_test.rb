# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class HeaderTest < TestCase
    setup do
      @old_profile_header = AppProfiler.profile_header
      @old_profile_async_header = AppProfiler.profile_async_header
      AppProfiler.profile_header = "X-Testing"
      AppProfiler.profile_async_header = "X-Testing-Async"
    end

    teardown do
      AppProfiler.profile_header = @old_profile_header
      AppProfiler.profile_async_header = @old_profile_async_header
    end

    test ".profile_data_header" do
      assert_equal("x-testing-data", AppProfiler.profile_data_header)
    end

    test ".profile_header stores lowercase names" do
      assert_equal("x-testing", AppProfiler.profile_header)
    end

    test ".profile_async_header stores lowercase names" do
      assert_equal("x-testing-async", AppProfiler.profile_async_header)
    end

    test ".request_profile_header" do
      assert_equal("HTTP_X_TESTING", AppProfiler.request_profile_header)
    end
  end
end
