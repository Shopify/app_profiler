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
      end

      class << self
        def upload(profile)
          Location.new(profile.file)
        end
      end
    end
  end
end
