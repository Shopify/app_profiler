# frozen_string_literal: true

module AppProfiler
  module Storage
    class FileStorage < BaseStorage
      class Location
        def initialize(file)
          @file = file
        end

        def url
          @file
        end

        def name
          @file.basename
        end
      end

      class << self
        def upload(profile)
          Location.new(profile.file)
        end

        def enqueue_upload(profile)
          upload(profile)
        end
      end
    end
  end
end
