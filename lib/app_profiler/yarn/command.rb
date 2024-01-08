# frozen_string_literal: true

module AppProfiler
  module Yarn
    module Command
      class YarnError < StandardError; end

      GECKO_VIEWER_PACKAGE = AppProfiler.gecko_viewer_package

      VALID_COMMANDS = [
        ["which", "yarn"],
        ["yarn", "init", "--yes"],
        ["yarn", "add", "speedscope", "--dev", "--ignore-workspace-root-check"],
        ["yarn", "run", "speedscope", /.*\.json/],
        ["yarn", "add", GECKO_VIEWER_PACKAGE],
        ["yarn", "--cwd", "node_modules/firefox-profiler"],
        ["yarn", "--cwd", "node_modules/firefox-profiler", "start", "-k", "1000", /.*\.(json|json\.gz|gecko)\z/],
      ]

      private_constant(:VALID_COMMANDS)
      private_constant(:GECKO_VIEWER_PACKAGE)
      mattr_accessor(:yarn_setup, default: false)

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

      private

      def ensure_command_valid(command)
        unless valid_command?(command)
          raise YarnError, "Illegal command: #{command.join(" ")}."
        end
      end

      def valid_command?(command)
        # Allow gecko viewer package to be overridden by railtie by detecting
        # if it was changed from the default
        if AppProfiler.gecko_viewer_package != GECKO_VIEWER_PACKAGE &&
            !VALID_COMMANDS.include?(["yarn", "add", AppProfiler.gecko_viewer_package])
          VALID_COMMANDS.append(["yarn", "add", AppProfiler.gecko_viewer_package])
        end
        VALID_COMMANDS.any? do |valid_command|
          valid_command.zip(command).all? do |valid_part, part|
            part.match?(valid_part)
          end
        end
      end

      def ensure_yarn_installed
        exec("which", "yarn", silent: true) do
          raise(
            YarnError,
            <<~MSG.squish
              `yarn` command not found.
              Please install `yarn` or make it available in PATH.
            MSG
          )
        end
        self.yarn_setup = true
      end

      def package_json_exists?
        AppProfiler.root.join("package.json").exist?
      end

      def exec(*command, silent: false)
        ensure_command_valid(command)

        if silent
          system(*command, out: File::NULL).tap { |return_code| yield unless return_code }
        else
          system(*command).tap { |return_code| yield unless return_code }
        end
      end
    end
  end
end
