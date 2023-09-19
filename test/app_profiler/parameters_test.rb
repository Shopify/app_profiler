# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class ParametersTest < TestCase
    test "#valid? is always true" do
      assert_predicate Parameters.new, :valid?
    end

    test "#autoredirect is false by default" do
      assert_not_predicate Parameters.new, :autoredirect
      assert_predicate Parameters.new(autoredirect: true), :autoredirect
    end

    test "#mode is :wall by default" do
      assert_equal :wall, Parameters.new.to_h.fetch(:mode)
    end

    test "#async is false by default" do
      assert_not_predicate Parameters.new, :async
      assert_predicate Parameters.new(async: true), :async
    end
  end
end
