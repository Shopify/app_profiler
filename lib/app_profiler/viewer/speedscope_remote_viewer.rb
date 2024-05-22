# frozen_string_literal: true

require "app_profiler/viewer/speedscope_remote_viewer/base_middleware"
require "app_profiler/viewer/speedscope_remote_viewer/middleware"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewer < BaseViewer
      class << self
        def view(profile, params = {})
          new(profile).view(**params)
        end
      end

      def initialize(profile)
        super()
        @profile = profile
      end

      def view(response: nil, autoredirect: nil, async: false)
        id = Middleware.id(@profile.file)

        if response && response[0].to_i < 500
          if autoredirect
            response[0] = 303
            response[1]["Location"] = "/app_profiler/#{id}"
          elsif AppProfiler.profile_header
            response[1][AppProfiler.profile_header] = "/app_profiler/#{id}"
          end
        else
          AppProfiler.logger.info("[Profiler] Profile available at /app_profiler/#{id}\n")
        end
      end
    end
  end
end
