# frozen_string_literal: true

require "active_support/deprecation/constant_accessor"
require "app_profiler/viewer/speedscope_remote_viewer/middleware"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewer < BaseViewer
      include ActiveSupport::Deprecation::DeprecatedConstantAccessor
      deprecate_constant(
        "BaseMiddleware",
        "AppProfiler::Viewer::BaseMiddleware",
        deprecator: AppProfiler.deprecator,
      )
      NAME = "speedscope"

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
          response[1]["location"] = "/app_profiler/#{NAME}/viewer/#{id}"
          response[0] = 303
        else
          AppProfiler.logger.info("[Profiler] Profile available at /app_profiler/#{id}\n")
        end
      end
    end
  end
end
