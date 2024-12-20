# frozen_string_literal: true

require "app_profiler/viewer/firefox_remote_viewer/middleware"

module AppProfiler
  module Viewer
    class FirefoxRemoteViewer < BaseViewer
      NAME = "firefox"

      class << self
        def remote?
          true
        end
      end

      def initialize(profile)
        super()
        @profile = profile
      end

      def view(response: nil, autoredirect: nil, async: false)
        id = Middleware.id(@profile.file)

        if response && response[0].to_i < 500
          response[1]["Location"] = "/app_profiler/#{NAME}/viewer/#{id}"
          response[0] = 303
        else
          AppProfiler.logger.info("[Profiler] Profile available at /app_profiler/#{id}\n")
        end
      end
    end
  end
end
