# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class ProfileIdTest < TestCase
    test ".current memoization" do
      ProfileId::Current.reset

      id = ProfileId.current
      assert_same(id, ProfileId.current)
    end
  end
end
