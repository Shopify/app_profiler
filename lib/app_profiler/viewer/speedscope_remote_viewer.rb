# frozen_string_literal: true

require "app_profiler/viewer/speedscope_remote_viewer/base_middleware"
require "app_profiler/viewer/speedscope_remote_viewer/middleware"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewer < BaseViewer
      class << self
        def view(profile)
          new(profile).view
        end
      end

      def initialize(profile)
        super()
        @profile = profile
      end

      def view
        id = Middleware.id(@profile.file)
        AppProfiler.logger.info("[Profiler] Profile available at /app_profiler/#{id}\n")
      end
    end
  end
end
