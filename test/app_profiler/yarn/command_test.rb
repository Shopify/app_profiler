# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Yarn
    class CommandTest < TestCase
      include(Command)

      setup do
        @yarn_initialized = true
      end

      teardown do
        @yarn_initialized = false
      end

      test "#yarn allows add speedscope" do
        expects(:system).with(
          "yarn", "add", "speedscope", "--dev", "--ignore-workspace-root-check"
        ).returns(true)

        yarn("add", "speedscope", "--dev", "--ignore-workspace-root-check")
      end

      test "#yarn allows init" do
        expects(:system).with("yarn", "init", "--yes").returns(true)

        yarn("init", "--yes")
      end

      test "#yarn allows run" do
        expects(:system).with("yarn", "run", "speedscope", "\"profile.json\"").returns(true)

        yarn("run", "speedscope", "\"profile.json\"")
      end

      test "#yarn disallows run" do
        expects(:system).with("yarn", "hack").never

        error = assert_raises(Command::YarnError) do
          yarn("hack")
        end

        assert_equal(<<~MSG.squish, error.message)
          Illegal command: yarn hack.
        MSG
      end
    end
  end
end
