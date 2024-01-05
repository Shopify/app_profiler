# frozen_string_literal: true

require "app_profiler/yarn/command"
require "app_profiler/yarn/with_firefox_profiler"

module AppProfiler
  module Viewer
    class FirefoxProfileViewer < BaseViewer
      include Yarn::WithFirefoxProfile

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
        yarn("--cwd", "node_modules/firefox-profiler", "start", @profile.file.to_s)
      end
    end
  end
end
