# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewerTest < TestCase
      test ".view initializes and calls #view" do
        SpeedscopeRemoteViewer.any_instance.expects(:view)

        profile = Profile.new(stackprof_profile)
        SpeedscopeRemoteViewer.view(profile)
      end

      test "#view logs middleware URL" do
        profile = Profile.new(stackprof_profile)

        viewer = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        AppProfiler.logger.expects(:info).with(
          "[Profiler] Profile available at /app_profiler/#{id}\n"
        )

        viewer.view
      end

      test "#view with autoredirect redirects to URL" do
        response = [200, {}, ["OK"]]
        profile = Profile.new(stackprof_profile)

        viewer = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        viewer.view(response: response, autoredirect: true)

        assert_equal(303, response[0])
        assert_equal("/app_profiler/#{id}", response[1]["Location"])
      end

      test "#view with configured autoredirect redirects to URL" do
        response = [200, {}, ["OK"]]
        profile = Profile.new(stackprof_profile)

        viewer = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        with_autoredirect do
          viewer.view(response: response)
        end

        assert_equal(303, response[0])
        assert_equal("/app_profiler/#{id}", response[1]["Location"])
      end
    end
  end
end
