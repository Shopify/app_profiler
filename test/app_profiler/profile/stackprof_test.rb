# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class StackprofProfileTest < TestCase
    test ".from_stackprof raises ArgumentError when mode is not present" do
      error = assert_raises(ArgumentError) do
        profile_without_mode = stackprof_profile.tap { |data| data.delete(:mode) }
        Profile.from_stackprof(profile_without_mode)
      end
      assert_equal("invalid profile data", error.message)
    end

    test ".from_stackprof assigns id and context metadata" do
      profile = Profile.from_stackprof(stackprof_profile(metadata: { id: "foo", context: "bar" }))

      assert_equal("foo", profile.id)
      assert_equal("bar", profile.context)
    end

    test ".from_stackprof assigns random id when id is not present" do
      SecureRandom.expects(:hex).returns("mock")

      params_without_id = stackprof_profile.tap { |data| data[:metadata].delete(:id) }
      profile = Profile.from_stackprof(params_without_id)

      assert_equal("mock", profile.id)
    end

    test ".from_stackprof removes id and context metadata from profile data" do
      profile = Profile.from_stackprof(stackprof_profile(metadata: { id: "foo", context: "bar" }))

      assert_not_operator(profile[:metadata], :key?, :id)
      assert_not_operator(profile[:metadata], :key?, :context)
    end

    test "#id" do
      profile = StackprofProfile.new(stackprof_profile, id: "pass")

      assert_equal("pass", profile.id)
    end

    test "#id is random hex by default" do
      SecureRandom.expects(:hex).returns("mock")

      profile = StackprofProfile.new(stackprof_profile)

      assert_equal("mock", profile.id)
    end

    test "#id is random hex when passed as empty string" do
      SecureRandom.expects(:hex).returns("mock")

      profile = StackprofProfile.new(stackprof_profile, id: "")

      assert_equal("mock", profile.id)
    end

    test "#context" do
      profile = StackprofProfile.new(stackprof_profile, context: "development")

      assert_equal("development", profile.context)
    end

    test "#valid? is false when mode is not present" do
      profile = StackprofProfile.new({})

      assert_not_predicate(profile, :valid?)
    end

    test "#valid? is true when mode is present" do
      profile = StackprofProfile.new({ mode: :cpu })

      assert_predicate(profile, :valid?)
    end

    test "#mode" do
      profile = StackprofProfile.new(stackprof_profile(mode: "object"))

      assert_equal("object", profile.mode)
    end

    test "#view" do
      profile = StackprofProfile.new(stackprof_profile)

      Viewer::SpeedscopeViewer.expects(:view).with(profile)

      profile.view
    end

    test "#upload" do
      profile = StackprofProfile.new(stackprof_profile)

      AppProfiler.stubs(:storage).returns(MockStorage)
      MockStorage.expects(:upload).with(profile).returns("some data")

      assert_equal("some data", profile.upload)
    end

    test "#upload returns nil if an error was raised" do
      profile = StackprofProfile.new(stackprof_profile)

      AppProfiler.storage.stubs(:upload).raises(StandardError, "upload error")

      assert_nil(profile.upload)
    end

    test "#file creates json file" do
      profile_data = stackprof_profile(mode: "wall")
      profile      = StackprofProfile.new(profile_data)

      assert_match(/.*\.json/, profile.file.to_s)
      assert_equal(profile_data, JSON.parse(profile.file.read, symbolize_names: true))
    end

    test "#file creates file only once" do
      profile = StackprofProfile.new(stackprof_profile)

      assert_predicate(profile.file, :exist?)

      profile.file.delete

      assert_not_predicate(profile.file, :exist?)
    end

    test "#[] forwards to profile data" do
      profile = StackprofProfile.new(stackprof_profile(interval: 10_000))

      assert_equal(10_000, profile[:interval])
    end

    test "#path raises an UnsafeFilename exception given chars not in allow list" do
      assert_raises(AppProfiler::Profile::UnsafeFilename) do
        profile = Profile.from_stackprof(stackprof_profile(metadata: { id: "|`@${}", context: "bar" }))
        profile.file
      end
    end

    test "#file uses custom profile_file_prefix block when provided" do
      profile = StackprofProfile.new(stackprof_profile)

      AppProfiler.stubs(:profile_file_prefix).returns(-> { "want-something-different" })
      assert_match(/want-something-different-/, File.basename(profile.file.to_s))
    end

    test "#file uses default prefix format when no custom profile_file_prefix block is provided" do
      travel_to Time.zone.local(2022, 10, 06, 12, 11, 10) do
        profile = StackprofProfile.new(stackprof_profile)
        assert_match(/^20221006-121110/, File.basename(profile.file.to_s))
      end
    end
  end
end
