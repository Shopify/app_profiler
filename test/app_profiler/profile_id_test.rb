# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class ProfileIdTest < TestCase
    test ".current memoization" do
      ProfileId::Current.reset

      id = ProfileId.current
      assert_same(id, ProfileId.current)
    end

    test "ProfileId is different for different threads" do
      ProfileId::Current.reset
      id1, id2 = ""
      Thread.new do
        id1 = ProfileId.current
      end

      Thread.new do
        id2 = ProfileId.current
      end

      assert_not_same(id1, id2)
    end

    test "ProfileId is different after reset" do
      id1 = ProfileId.current
      ProfileId::Current.reset
      id2 = ProfileId.current
      assert_not_same(id1, id2)
    end
  end
end
