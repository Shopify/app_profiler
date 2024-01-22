# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class SpeedscopeViewerTest < TestCase
      test ".view initializes and calls #view" do
        SpeedscopeViewer.any_instance.expects(:view)

        profile = Profile.from_stackprof(stackprof_profile)
        SpeedscopeViewer.view(profile)
      end

      test "#view opens profile in speedscope and sets up yarn" do
        profile = Profile.from_stackprof(stackprof_profile)

        viewer = SpeedscopeViewer.new(profile)
        viewer.expects(:system).with("which", "yarn", out: File::NULL).returns(true)
        viewer.expects(:system).with("yarn", "init", "--yes").returns(true)
        viewer.expects(:system).with(
          "yarn", "add", "speedscope", "--dev", "--ignore-workspace-root-check"
        ).returns(true)
        viewer.expects(:system).with("yarn", "run", "speedscope", profile.file.to_s).returns(true)

        viewer.view

        assert_predicate(Yarn::Command, :yarn_setup)
      ensure
        Yarn::Command.yarn_setup = false
      end

      test "#view doesn't init when package.json exists" do
        profile = Profile.from_stackprof(stackprof_profile)

        AppProfiler.root.mkpath
        AppProfiler.root.join("package.json").write("{}")

        viewer = SpeedscopeViewer.new(profile)
        viewer.expects(:system).with("which", "yarn", out: File::NULL).returns(true)
        viewer.expects(:system).with(
          "yarn", "add", "speedscope", "--dev", "--ignore-workspace-root-check"
        ).returns(true)
        viewer.expects(:system).with("yarn", "run", "speedscope", profile.file.to_s).returns(true)

        viewer.view

        assert_predicate(Yarn::Command, :yarn_setup)
      ensure
        Yarn::Command.yarn_setup = false
        AppProfiler.root.rmtree
      end

      test "#view doesn't add when speedscope exists" do
        profile = Profile.from_stackprof(stackprof_profile)

        AppProfiler.root.mkpath
        AppProfiler.root.join("node_modules/speedscope").mkpath

        viewer = SpeedscopeViewer.new(profile)
        viewer.expects(:system).with("which", "yarn", out: File::NULL).returns(true)
        viewer.expects(:system).with("yarn", "init", "--yes").returns(true)
        viewer.expects(:system).with("yarn", "run", "speedscope", profile.file.to_s).returns(true)

        viewer.view

        assert_predicate(Yarn::Command, :yarn_setup)
      ensure
        Yarn::Command.yarn_setup = false
        AppProfiler.root.rmtree
      end

      test "#view only opens profile in speedscope if yarn is already setup" do
        profile = Profile.from_stackprof(stackprof_profile)

        with_yarn_setup do
          viewer = SpeedscopeViewer.new(profile)
          viewer.expects(:system).with("yarn", "run", "speedscope", profile.file.to_s).returns(true)

          viewer.view
        end
      end

      test "#view raises YarnError when yarn command fails" do
        profile = Profile.from_stackprof(stackprof_profile)
        viewer = SpeedscopeViewer.new(profile)
        viewer.expects(:system).returns(false)

        assert_raises(SpeedscopeViewer::YarnError) do
          viewer.view
        end
      end
    end
  end
end
