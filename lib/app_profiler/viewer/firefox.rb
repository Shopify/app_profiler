# frozen_string_literal: true

require "app_profiler/exec"

module AppProfiler
  module Viewer
    class FirefoxViewer < BaseViewer
      include Exec

      class ProfileViewerError < StandardError; end

      VALID_COMMANDS = [
        ["which", "profile-viewer"],
        ["gem", "install", "profile-viewer"],
        ["profile-viewer", /.*\.json/],
      ]
      private_constant(:VALID_COMMANDS)

      class << self
        def view(profile, params = {})
          new(profile).view(**params)
        end
      end

      def valid_commands
        VALID_COMMANDS
      end

      def initialize(profile)
        super()
        @profile = profile
      end

      def view(_params = {})
        profile_viewer(@profile.file.to_s)
      end

      private

      def setup_profile_viewer
        exec("which", "profile-viewer", silent: true) do
          gem_install("profile_viewer")
        end
        @profile_viewer_initialized = true
      end

      def profile_viewer_setup
        @profile_viewer_initialized || false
      end

      def gem_install(gem)
        exec("gem", "install", gem) do
          raise ProfileViewerError, "Failed to run gem install #{gem}."
        end
      end

      def profile_viewer(path)
        setup_profile_viewer unless profile_viewer_setup

        pid = fork do
          Bundler.with_clean_env do
            exec("profile-viewer", path) do
              raise ProfileViewerError, "Failed to run profile-viewer #{path}."
            end
          end
        end

        sleep(1)

        Process.kill(pid)
      end
    end
  end
end
