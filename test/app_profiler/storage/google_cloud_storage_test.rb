# frozen_string_literal: true

require "test_helper"
require "app_profiler/storage/google_cloud_storage"

module AppProfiler
  module Storage
    class GoogleCloudStorageTest < AppProfiler::TestCase
      TEST_BUCKET_NAME = "app-profile-test"
      TEST_FILE_URL = "https://www.example.com/uploaded.json"

      test "upload file" do
        with_mock_gcs_bucket do
          uploaded_file = GoogleCloudStorage.upload(stub(context: "context", file: json_test_file))
          assert_equal(uploaded_file.url, TEST_FILE_URL)
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
        with_mock_gcs_bucket do
          uploaded_file = GoogleCloudStorage.upload(stub(context: "context", file: json_test_file))
          assert_equal(uploaded_file.url, TEST_FILE_URL)
          assert(event_emitted)
        end
      end

      private

      def json_test_file
        file_fixture("test_file.json")
      end

      def with_mock_gcs_bucket
        file = Google::Cloud::Storage::File.new
        file.stubs(:url).returns(TEST_FILE_URL)

        bucket = Google::Cloud::Storage::Bucket.new
        bucket.expects(:create_file).once.with do |input, filename, data|
          assert_equal(Zlib::GzipReader.new(input).read, File.open(json_test_file).read)
          assert_equal(filename, "context/test_file.json")
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
