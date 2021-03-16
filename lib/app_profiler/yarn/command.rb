# frozen_string_literal: true
module AppProfiler
  module Yarn
    module Command
      class YarnError < StandardError; end

      mattr_accessor :yarn_setup, default: false

      def yarn(command)
        setup_yarn unless yarn_setup
        exec("yarn #{command}") do
          raise YarnError, "Failed to run #{command}."
        end
      end

      def setup_yarn
        ensure_yarn_installed
        yarn("init --yes") unless package_json_exists?
      end

      private

      def ensure_yarn_installed
        exec("which yarn > /dev/null") do
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

      def exec(command)
        system(command).tap do |return_code|
          yield unless return_code
        end
      end
    end
  end
end
