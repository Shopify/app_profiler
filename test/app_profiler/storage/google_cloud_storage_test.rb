# frozen_string_literal: true

require "test_helper"
require "app_profiler/storage/google_cloud_storage"

module AppProfiler
  module Storage
    class GoogleCloudStorageTest < AppProfiler::TestCase
      TEST_BUCKET_NAME = "app-profile-test"
      TEST_FILE_URL = "https://www.example.com/uploaded.json"

      def teardown
        GoogleCloudStorage.reset_queue
      end

      test "upload file" do
        profile = profile_from_stackprof
        with_mock_gcs_bucket(profile) do
          uploaded_file = GoogleCloudStorage.upload(profile)
          assert_equal(uploaded_file.url, TEST_FILE_URL)
          assert_not_predicate(profile.file, :exist?)
        end
      end

      test "gzipped encoding" do
        file = json_test_file.open
        reader = GoogleCloudStorage.send(:gzipped_reader, file)
        content = Zlib::GzipReader.new(reader)

        json_test_file.open do |f2| # reopen the file
          assert_equal(f2.read, content.read)
        end
      end

      test "directory includes context" do
        assert_equal(
          GoogleCloudStorage.send(:gcs_filename, stub(context: "context", file: Pathname.new("foo"))),
          "context/foo"
        )
      end

      test "'gcs_upload.app_profiler' event is emitted through ActiveSupport::Notifications" do
        event_emitted = false
        monotonic_subscribe_or_subscribe("gcs_upload.app_profiler") do |_, _, _, _, tags|
          assert(tags[:file_size].present?)
          event_emitted = true
        end
        profile = profile_from_stackprof
        with_mock_gcs_bucket(profile) do
          uploaded_file = GoogleCloudStorage.upload(profile)
          assert_equal(uploaded_file.url, TEST_FILE_URL)
          assert(event_emitted)
        end
      end

      test ".process_queue is a no-op when nothing to upload" do
        StackprofProfile.any_instance.expects(:upload).never
        GoogleCloudStorage.send(:process_queue)
      end

      test ".process_queue uploads" do
        with_stubbed_process_queue_thread do
          profile = profile_from_stackprof
          @called = false
          AppProfiler.profile_enqueue_success = -> { @called = true }
          GoogleCloudStorage.enqueue_upload(profile)
          assert(@called)

          @num_success = 0
          @num_failures = 0

          AppProfiler.after_process_queue = ->(num_success, num_failures) do
            @num_success = num_success
            @num_failures = num_failures
          end
          GoogleCloudStorage.send(:process_queue)
          assert_equal(1, @num_success)
          assert_equal(0, @num_failures)
        ensure
          AppProfiler.profile_enqueue_success = nil
        end
      end

      test "profile is dropped when the queue is full" do
        with_stubbed_process_queue_thread do
          AppProfiler.upload_queue_max_length.times do
            GoogleCloudStorage.enqueue_upload(profile_from_stackprof)
          end
          dropped_profile = BaseProfile.from_stackprof(profile_from_stackprof)
          AppProfiler.logger.expects(:info).with { |value| value =~ /upload queue is full/ }

          @called = false
          AppProfiler.profile_enqueue_success = -> { @called = true }
          refute(@called)

          @profile = nil
          AppProfiler.profile_enqueue_failure = ->(profile) { @profile = profile }
          GoogleCloudStorage.enqueue_upload(dropped_profile)
          assert_equal(dropped_profile, @profile)
        ensure
          AppProfiler.profile_enqueue_success = nil
          AppProfiler.profile_enqueue_failure = nil
        end
      end

      test "process_queue_thread is alive after first upload" do
        th = GoogleCloudStorage.instance_variable_get(:@process_queue_thread)

        refute(th&.alive?)
        GoogleCloudStorage.enqueue_upload(profile_from_stackprof)
        th = GoogleCloudStorage.instance_variable_get(:@process_queue_thread)
        assert(th.alive?)
      end

      private

      def with_stubbed_process_queue_thread
        # Stub out the thread creation, so that tests are not flaky.
        GoogleCloudStorage.stubs(:process_queue_thread)
        yield
      ensure
        GoogleCloudStorage.unstub(:process_queue_thread)
      end

      def profile_from_stackprof
        BaseProfile.from_stackprof(stackprof_profile(metadata: { id: "bar" }))
      end

      def json_test_file
        file_fixture("test_file.json")
      end

      def with_mock_gcs_bucket(profile)
        file = Google::Cloud::Storage::File.new
        file.stubs(:url).returns(TEST_FILE_URL)

        bucket = Google::Cloud::Storage::Bucket.new
        bucket.expects(:create_file).once.with do |input, filename, data|
          assert_equal(Zlib::GzipReader.new(input).read, profile.file.open.read)
          assert_equal(filename, GoogleCloudStorage.send(:gcs_filename, profile))
          assert_equal(data[:content_type], "application/json")
          assert_equal(data[:content_encoding], "gzip")
        end.returns(file)

        GoogleCloudStorage.stubs(:bucket).returns(bucket)

        yield
      end

      def monotonic_subscribe_or_subscribe(topic, &block)
        if ActiveSupport::Notifications.respond_to?(:monotonic_subscribe)
          ActiveSupport::Notifications.monotonic_subscribe(topic, &block)
        else
          ActiveSupport::Notifications.subscribe(topic, &block)
        end
      end
    end
  end
end
