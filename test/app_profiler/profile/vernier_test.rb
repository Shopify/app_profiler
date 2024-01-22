# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class VernierProfileTest < TestCase
    # test ".from_vernier raises ArgumentError when mode is not present" do
    #  error = assert_raises(ArgumentError) do
    #    profile_without_mode = vernier_profile.tap { |data| data.data.delete(:mode) }
    #    Profile.from_vernier(profile_without_mode)
    #  end
    #  assert_equal("invalid profile data", error.message)
    # end

    test ".from_vernier assigns id and context metadata" do
      profile = Profile.from_vernier(vernier_profile(metadata: { id: "foo", context: "bar" }))

      assert_equal("foo", profile.id)
      assert_equal("bar", profile.context)
    end

    test ".from_vernier assigns random id when id is not present" do
      SecureRandom.expects(:hex).returns("mock")

      params_without_id = vernier_profile(vernier_params).tap { |data| data.meta.delete(:id) }
      profile = Profile.from_vernier(params_without_id)

      assert_equal("mock", profile.id)
    end

    # test ".from_vernier removes id and context metadata from profile data" do
    #  profile = Profile.from_vernier(vernier_profile(metadata: { id: "foo", context: "bar" }))

    #  assert_not_operator(profile[:metadata], :key?, :id)
    #  assert_not_operator(profile[:metadata], :key?, :context)
    # end

    test "#id" do
      profile = VernierProfile.new(vernier_profile, id: "pass")

      assert_equal("pass", profile.id)
    end

    test "#id is random hex by default" do
      SecureRandom.expects(:hex).returns("mock")

      profile = VernierProfile.new(vernier_profile)

      assert_equal("mock", profile.id)
    end

    test "#id is random hex when passed as empty string" do
      SecureRandom.expects(:hex).returns("mock")

      profile = VernierProfile.new(vernier_profile, id: "")

      assert_equal("mock", profile.id)
    end

    test "#context" do
      profile = VernierProfile.new(vernier_profile, context: "development")

      assert_equal("development", profile.context)
    end

    # test "#valid? is false when mode is not present" do
    #  profile = VernierProfile.new(vernier_profile)

    #  assert_not_predicate(profile, :valid?)
    # end

    test "#valid? is true when mode is present" do
      profile = VernierProfile.new(vernier_profile({ mode: :cpu }))

      assert_predicate(profile, :valid?)
    end

    test "#mode" do
      profile = VernierProfile.new(vernier_profile(metadata: { mode: "retained" }))

      assert_equal("retained", profile.mode)
    end

    test "#view" do
      profile = VernierProfile.new(vernier_profile)

      Viewer::FirefoxViewer.expects(:view).with(profile)

      profile.view
    end

    test "#upload" do
      profile = VernierProfile.new(vernier_profile)

      AppProfiler.stubs(:storage).returns(MockStorage)
      MockStorage.expects(:upload).with(profile).returns("some data")

      assert_equal("some data", profile.upload)
    end

    test "#upload returns nil if an error was raised" do
      profile = VernierProfile.new(vernier_profile)

      AppProfiler.storage.stubs(:upload).raises(StandardError, "upload error")

      assert_nil(profile.upload)
    end

    test "#file creates json file" do
      profile_data = vernier_profile(mode: "wall")
      profile      = VernierProfile.new(profile_data)

      assert_match(/.*\.json/, profile.file.to_s)
      assert_equal(profile_data.to_h, JSON.parse(profile.file.read, symbolize_names: true))
    end

    test "#file creates file only once" do
      profile = VernierProfile.new(vernier_profile)

      assert_predicate(profile.file, :exist?)

      profile.file.delete

      assert_not_predicate(profile.file, :exist?)
    end

    test "#to_h returns profile data" do
      profile_data = vernier_profile
      profile      = VernierProfile.new(profile_data)

      assert_equal(profile_data.to_h, profile.to_h)
    end

    test "#[] forwards to profile metadata" do
      profile = VernierProfile.new(vernier_profile(metadata: { interval: 10_000 }))

      assert_equal(10_000, profile[:interval])
    end

    test "#path raises an UnsafeFilename exception given chars not in allow list" do
      assert_raises(AppProfiler::Profile::UnsafeFilename) do
        profile = Profile.from_vernier(vernier_profile(metadata: { id: "|`@${}", context: "bar" }))
        profile.file
      end
    end

    test "#file uses custom profile_file_prefix block when provided" do
      profile = VernierProfile.new(vernier_profile)

      AppProfiler.stubs(:profile_file_prefix).returns(-> { "want-something-different" })
      assert_match(/want-something-different-/, File.basename(profile.file.to_s))
    end

    test "#file uses default prefix format when no custom profile_file_prefix block is provided" do
      travel_to Time.zone.local(2022, 10, 06, 12, 11, 10) do
        profile = VernierProfile.new(vernier_profile)
        assert_match(/^20221006-121110/, File.basename(profile.file.to_s))
      end
    end
  end
end
