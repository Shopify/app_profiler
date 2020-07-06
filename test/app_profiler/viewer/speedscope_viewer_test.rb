# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class SpeedscopeViewerTest < TestCase
      test ".view initializes and calls #view" do
        SpeedscopeViewer.any_instance.expects(:view)

        profile = Profile.new(stackprof_profile)
        SpeedscopeViewer.view(profile)
      end

      test "#view opens profile in speedscope and sets up yarn" do
        profile = Profile.new(stackprof_profile)

        viewer = SpeedscopeViewer.new(profile)
        viewer.expects(:system).with("which yarn > /dev/null").returns(true)
        viewer.expects(:system).with("yarn init --yes").returns(true)
        viewer.expects(:system).with("yarn add --dev --ignore-workspace-root-check speedscope").returns(true)
        viewer.expects(:system).with("yarn run speedscope \"#{profile.file}\"").returns(true)

        viewer.view

        assert_predicate(SpeedscopeViewer, :yarn_setup)
      ensure
        SpeedscopeViewer.yarn_setup = false
      end

      test "#view only opens profile in speedscope if yarn is already setup" do
        profile = Profile.new(stackprof_profile)

        with_yarn_setup do
          viewer = SpeedscopeViewer.new(profile)
          viewer.expects(:system).with("yarn run speedscope \"#{profile.file}\"").returns(true)

          viewer.view
        end
      end

      test "#view raises YarnError when yarn command fails" do
        profile = Profile.new(stackprof_profile)
        viewer = SpeedscopeViewer.new(profile)
        viewer.expects(:system).returns(false)

        assert_raises(SpeedscopeViewer::YarnError) do
          viewer.view
        end
      end

      private

      def with_yarn_setup
        old_yarn_setup = SpeedscopeViewer.yarn_setup
        SpeedscopeViewer.yarn_setup = true
        yield
      ensure
        SpeedscopeViewer.yarn_setup = old_yarn_setup
      end
    end
  end
end
