# frozen_string_literal: true

module AppProfiler
  class MockStorage < Storage::FileStorage
    class FileInfo
      attr_reader :url

      def initialize(url)
        @url = url
      end
    end

    class << self
      def upload(*)
        super
        FileInfo.new("/profile/file.json")
      end
    end
  end
end
