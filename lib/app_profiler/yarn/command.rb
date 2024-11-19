# frozen_string_literal: true

require "app_profiler/exec"

module AppProfiler
  module Yarn
    module Command
      include Exec

      class YarnError < StandardError; end

      VALID_COMMANDS = [
        ["which", "yarn"],
        ["yarn", "init", "--yes"],
        ["yarn", "add", "speedscope", "--dev", "--ignore-workspace-root-check"],
        ["yarn", "run", "speedscope", /.*\.json/],
        ["yarn", "add", "--dev", %r{.*/firefox-profiler}],
        ["yarn", "--cwd", %r{.*/firefox-profiler}],
        ["yarn", "--cwd", %r{.*/firefox-profiler}, "build-prod"],
      ]

      private_constant(:VALID_COMMANDS)

      def valid_commands
        VALID_COMMANDS
      end

      def yarn(command, *options)
        setup_yarn unless yarn_setup

        exec("yarn", command, *options) do
          raise YarnError, "Failed to run #{command}."
        end
      end

      def setup_yarn
        ensure_yarn_installed

        yarn("init", "--yes") unless package_json_exists?
      end

      def yarn_setup
        @yarn_initialized || false
      end

      def yarn_setup=(state)
        @yarn_initialized = state
      end

      private

      def ensure_yarn_installed
        exec("which", "yarn", silent: true) do
          raise(
            YarnError,
            <<~MSG.squish,
              `yarn` command not found.
              Please install `yarn` or make it available in PATH.
            MSG
          )
        end
        @yarn_initialized = true
      end

      def package_json_exists?
        AppProfiler.root.join("package.json").exist?
      end
    end
  end
end
