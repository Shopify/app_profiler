# frozen_string_literal: true

require "active_support/deprecation/constant_accessor"

module AppProfiler
  class BaseProfile
    INTERNAL_METADATA_KEYS = [:id, :context]
    private_constant :INTERNAL_METADATA_KEYS
    class UnsafeFilename < StandardError; end

    attr_reader :context

    delegate :[], to: :@data

    class << self
      # This function should not be called if `StackProf.results` returns nil.
      def from_stackprof(data)
        options = INTERNAL_METADATA_KEYS.map { |key| [key, data[:metadata]&.delete(key)] }.to_h

        StackprofProfile.new(data, **options).tap do |profile|
          raise ArgumentError, "invalid profile data" unless profile.valid?
        end
      end

      def from_vernier(data)
        options = INTERNAL_METADATA_KEYS.map { |key| [key, data[:meta]&.delete(key)] }.to_h

        VernierProfile.new(data, **options).tap do |profile|
          raise ArgumentError, "invalid profile data" unless profile.valid?
        end
      end
    end

    # `data` is assumed to be a Hash for Stackprof,
    # a vernier "result" object for vernier
    def initialize(data, id: nil, context: nil)
      ProfileId.current = id if id.present?

      @context = context
      @data    = data

      metadata[PROFILE_BACKEND_METADATA_KEY] = self.class.backend_name
      metadata[PROFILE_ID_METADATA_KEY] = ProfileId.current
    end

    def id
      metadata[PROFILE_ID_METADATA_KEY]
    end

    def upload
      AppProfiler.storage.upload(self).tap do |upload|
        if upload && defined?(upload.url)
          AppProfiler.logger.info(
            <<~INFO.squish,
              [Profiler] data uploaded:
              profile_url=#{upload.url}
              profile_viewer_url=#{AppProfiler.profile_url(upload)}
            INFO
          )
        end
      end
    rescue => error
      AppProfiler.logger.info(
        "[Profiler] failed to upload profile error_class=#{error.class} error_message=#{error.message}",
      )
      nil
    end

    def enqueue_upload
      AppProfiler.storage.enqueue_upload(self)
    end

    def valid?
      mode.present?
    end

    def file
      @file ||= path.tap do |p|
        p.dirname.mkpath
        p.write(JSON.dump(@data))
      end
    end

    def to_h
      @data
    end

    def metadata
      raise NotImplementedError
    end

    def mode
      raise NotImplementedError
    end

    def format
      raise NotImplementedError
    end

    def view(params = {})
      raise NotImplementedError
    end

    private

    def path
      filename = if AppProfiler.profile_file_name.present?
        AppProfiler.profile_file_name.call(metadata) + format
      else
        [
          AppProfiler.profile_file_prefix.call,
          mode,
          id,
          Socket.gethostname,
        ].compact.join("-") << format
      end

      raise UnsafeFilename if /[^0-9A-Za-z.\-\_]/.match?(filename)

      AppProfiler.profile_root.join(filename)
    end
  end
end
