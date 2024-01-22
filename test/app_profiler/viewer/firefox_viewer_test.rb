# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class FirefoxViewerTest < TestCase
      test ".view initializes and calls #view" do
        FirefoxViewer.any_instance.expects(:view)

        profile = VernierProfile.new(vernier_profile)
        FirefoxViewer.view(profile)
      end

      test "#view logs middleware URL" do
        profile = VernierProfile.new(vernier_profile)

        viewer = FirefoxViewer.new(profile)
        id = FirefoxViewer::Middleware.id(profile.file)

        AppProfiler.logger.expects(:info).with(
          "[Profiler] Profile available at /app_profiler/#{id}\n"
        )

        viewer.view
      end

      test "#view with response redirects to URL" do
        response = [200, {}, ["OK"]]
        profile = VernierProfile.new(vernier_profile)

        viewer = FirefoxViewer.new(profile)
        id = FirefoxViewer::Middleware.id(profile.file)

        viewer.view(response: response)

        assert_equal(303, response[0])
        assert_equal("/app_profiler/firefox/viewer/#{id}", response[1]["Location"])
      end
    end
  end
end
