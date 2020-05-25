# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class ProfileTest < TestCase
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
      profile = Profile.new(stackprof_profile, id: "pass")

      assert_equal("pass", profile.id)
    end

    test "#id is random hex by default" do
      SecureRandom.expects(:hex).returns("mock")

      profile = Profile.new(stackprof_profile)

      assert_equal("mock", profile.id)
    end

    test "#id is random hex when passed as empty string" do
      SecureRandom.expects(:hex).returns("mock")

      profile = Profile.new(stackprof_profile, id: "")

      assert_equal("mock", profile.id)
    end

    test "#context" do
      profile = Profile.new(stackprof_profile, context: "development")

      assert_equal("development", profile.context)
    end

    test "#valid? is false when mode is not present" do
      profile = Profile.new({})

      assert_not_predicate(profile, :valid?)
    end

    test "#valid? is true when mode is present" do
      profile = Profile.new({ mode: :cpu })

      assert_predicate(profile, :valid?)
    end

    test "#mode" do
      profile = Profile.new(stackprof_profile(mode: "object"))

      assert_equal("object", profile.mode)
    end

    test "#view" do
      profile = Profile.new(stackprof_profile)

      AppProfiler.stubs(:viewer).returns(Viewer::SpeedscopeViewer)
      Viewer::SpeedscopeViewer.expects(:view).with(profile)

      profile.view
    end

    test "#upload" do
      profile = Profile.new(stackprof_profile)

      AppProfiler.stubs(:storage).returns(MockStorage)
      MockStorage.expects(:upload).with(profile).returns("some data")

      assert_equal("some data", profile.upload)
    end

    test "#upload returns nil if an error was raised" do
      profile = Profile.new(stackprof_profile)

      AppProfiler.storage.stubs(:upload).raises(StandardError, "upload error")

      assert_nil(profile.upload)
    end

    test "#file creates json file" do
      profile_data = stackprof_profile(mode: "wall")
      profile      = Profile.new(profile_data)

      assert_match(/.*\.json/, profile.file.to_s)
      assert_equal(profile_data, JSON.parse(profile.file.read, symbolize_names: true))
    end

    test "#file creates file only once" do
      profile = Profile.new(stackprof_profile)

      assert_predicate(profile.file, :exist?)

      profile.file.delete

      assert_not_predicate(profile.file, :exist?)
    end

    test "#to_h returns profile data" do
      profile_data = stackprof_profile
      profile      = Profile.new(profile_data)

      assert_equal(profile_data, profile.to_h)
    end

    test "#[] forwards to profile data" do
      profile = Profile.new(stackprof_profile(interval: 10_000))

      assert_equal(10_000, profile[:interval])
    end
  end
end
