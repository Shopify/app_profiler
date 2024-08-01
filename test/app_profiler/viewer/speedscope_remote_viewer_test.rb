# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewerTest < TestCase
      test ".view initializes and calls #view" do
        SpeedscopeRemoteViewer.any_instance.expects(:view)

        profile = BaseProfile.from_stackprof(stackprof_profile)
        SpeedscopeRemoteViewer.view(profile)
      end

      test "#view logs middleware URL" do
        profile = BaseProfile.from_stackprof(stackprof_profile)

        viewer = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        AppProfiler.logger.expects(:info).with(
          "[Profiler] Profile available at /app_profiler/#{id}\n",
        )

        viewer.view
      end

      test "#view with response sets the profiler header" do
        response = [200, {}, ["OK"]]
        profile = BaseProfile.from_stackprof(stackprof_profile)

        view = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        view.view(response: response)

        assert_equal(200, response[0])
        assert_equal("/app_profiler/#{id}", response[1][AppProfiler.profile_header])
      end

      test "#view with response redirects to URL when autoredirect is set" do
        response = [200, {}, ["OK"]]
        profile = BaseProfile.from_stackprof(stackprof_profile)

        viewer = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        viewer.view(response: response, autoredirect: true)

        assert_equal(303, response[0])
        assert_equal("/app_profiler/#{id}", response[1]["Location"])
      end
    end
  end
end
