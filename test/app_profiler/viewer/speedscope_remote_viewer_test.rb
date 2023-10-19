# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewerTest < TestCase
      test ".view initializes and calls #view" do
        SpeedscopeRemoteViewer.any_instance.expects(:view)

        profile = StackprofProfile.new(stackprof_profile)
        SpeedscopeRemoteViewer.view(profile)
      end

      test "#view logs middleware URL" do
        profile = StackprofProfile.new(stackprof_profile)

        viewer = SpeedscopeRemoteViewer.new(profile)
        id = SpeedscopeRemoteViewer::Middleware.id(profile.file)

        AppProfiler.logger.expects(:info).with(
          "[Profiler] Profile available at /app_profiler/#{id}\n"
        )

        viewer.view
      end

      private

      def with_yarn_setup
        old_yarn_setup = Yarn::Command.yarn_setup
        Yarn::Command.yarn_setup = true
        yield
      ensure
        Yarn::Command.yarn_setup = old_yarn_setup
      end
    end
  end
end
