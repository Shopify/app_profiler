# frozen_string_literal: true

require "app_profiler/yarn/command"
require "app_profiler/yarn/with_firefox_profiler"

module AppProfiler
  module Viewer
    class FirefoxProfileViewer < BaseViewer
      include Yarn::WithFirefoxProfile

      KEEPALIVE_TIMEOUT_MS = 1000 # NB: must match what is allow-listed in command.rb

      class << self
        def view(profile, params = {})
          new(profile).view(**params)
        end
      end

      def initialize(profile)
        super()
        @profile = profile
      end

      def view(_params = {})
        yarn("--cwd", "node_modules/firefox-profiler", "start", "-k", KEEPALIVE_TIMEOUT_MS.to_s, @profile.file.to_s)
      end
    end
  end
end
