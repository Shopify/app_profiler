# frozen_string_literal: true

module AppProfiler
  autoload :StackprofProfile, "app_profiler/profile/stackprof"
  autoload :VernierProfile, "app_profiler/profile/vernier"

  class Profile
    INTERNAL_METADATA_KEYS = [:id, :context]
    private_constant :INTERNAL_METADATA_KEYS
    class UnsafeFilename < StandardError; end

    attr_reader :id, :context

    # This function should not be called if `StackProf.results` returns nil.
    def self.from_stackprof(data)
      options = INTERNAL_METADATA_KEYS.map { |key| [key, data[:metadata]&.delete(key)] }.to_h

      StackprofProfile.new(data, **options).tap do |profile|
        raise ArgumentError, "invalid profile data" unless profile.valid?
      end
    end

    def self.from_vernier(data)
      # NB: we don't delete here, that is causing a segfault in vernier. Divergent behaviour from stackprof,
      # as the special metadata keys "id" and "context" are preserved into the metadata, but maybe that isn't so bad.
      options = INTERNAL_METADATA_KEYS.map { |key| [key, data.meta.clone[key]] }.to_h

      VernierProfile.new(data, **options).tap do |profile|
        raise ArgumentError, "invalid profile data" unless profile.valid?
      end
    end

    # `data` is assumed to be a Hash for Stackprof,
    # a vernier "result" object for vernier
    def initialize(data, id: nil, context: nil)
      @id      = id.presence || SecureRandom.hex
      @context = context
      @data    = data
    end

    def upload
      AppProfiler.storage.upload(self).tap do |upload|
        if upload && defined?(upload.url)
          AppProfiler.logger.info(
            <<~INFO.squish
              [Profiler] data uploaded:
              profile_url=#{upload.url}
              profile_viewer_url=#{AppProfiler.profile_url(upload)}
            INFO
          )
        end
      end
    rescue => error
      AppProfiler.logger.info(
        "[Profiler] failed to upload profile error_class=#{error.class} error_message=#{error.message}"
      )
      nil
    end

    def enqueue_upload
      AppProfiler.storage.enqueue_upload(self)
    end

    def file
      raise NotImplementedError
    end

    def to_h
      raise NotImplementedError
    end

    def valid?
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
      filename = [
        AppProfiler.profile_file_prefix.call,
        mode,
        id,
        Socket.gethostname,
      ].compact.join("-") << format

      raise UnsafeFilename if /[^0-9A-Za-z.\-\_]/.match?(filename)

      AppProfiler.profile_root.join(filename)
    end
  end
end
