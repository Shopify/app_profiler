# frozen_string_literal: true

module AppProfiler
  module Storage
    class BaseStorage
      class_attribute :bucket_name, default: "profiles"
      class_attribute :credentials, default: {}

      class << self
        def upload(_profile)
          raise NotImplementedError
        end

        def enqueue_upload(_profile)
          raise NotImplementedError
        end

        def upload_path(_profile)
          raise NotImplementedError
        end
      end
    end
  end
end
