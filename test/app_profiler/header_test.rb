# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class HeaderTest < TestCase
    setup do
      @old_profile_header = AppProfiler.profile_header
      AppProfiler.profile_header = "X-Testing"
    end

    teardown do
      AppProfiler.profile_header = @old_profile_header
    end

    test ".profile_data_header" do
      assert_equal("X-Testing-Data", AppProfiler.profile_data_header)
    end

    test ".request_profile_header" do
      assert_equal("HTTP_X_TESTING", AppProfiler.request_profile_header)
    end
  end
end
