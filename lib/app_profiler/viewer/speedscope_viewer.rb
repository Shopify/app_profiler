# frozen_string_literal: true

module AppProfiler
  module Viewer
    class SpeedscopeViewer < BaseViewer
      mattr_accessor :yarn_setup, default: false

      class YarnError < StandardError; end

      class << self
        def view(profile)
          new(profile).view
        end
      end

      def initialize(profile)
        @profile = profile
      end

      def view
        yarn("run speedscope \"#{@profile.file}\"")
      end

      private

      def yarn(command)
        setup_yarn unless yarn_setup
        exec("yarn #{command}") do
          raise YarnError, "Failed to run #{command}."
        end
      end

      def setup_yarn
        ensure_yarn_installed
        yarn("init --yes") unless package_json_exists?
        yarn("add --dev speedscope")
      end

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
