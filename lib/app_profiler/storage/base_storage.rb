# frozen_string_literal: true

module AppProfiler
  module Storage
    class BaseStorage
      class_attribute :bucket_name, default: "profiles"
      class_attribute :credentials, default: {}

      def self.upload(_profile)
        raise NotImplementedError
      end

      def self.enqueue_upload(_profile)
        raise NotImplementedError
      end
    end
  end
end
