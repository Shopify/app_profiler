# frozen_string_literal: true

module AppProfiler
  class Profile
    INTERNAL_METADATA_KEYS = [:id, :context]
    private_constant :INTERNAL_METADATA_KEYS
    class UnsafeFilename < StandardError; end

    delegate    :[], to: :@data
    attr_reader :id, :context

    # This function should not be called if `StackProf.results` returns nil.
    def self.from_stackprof(data)
      options = INTERNAL_METADATA_KEYS.map { |key| [key, data[:metadata]&.delete(key)] }.to_h

      new(data, **options).tap do |profile|
        raise ArgumentError, "invalid profile data" unless profile.valid?
      end
    end

    # `data` is assumed to be a Hash.
    def initialize(data, id: nil, context: nil)
      @id      = id.presence || SecureRandom.hex
      @context = context
      @data    = data
    end

    def valid?
      mode.present?
    end

    def mode
      @data[:mode]
    end

    def view
      AppProfiler.viewer.view(self)
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
      @file ||= path.tap do |p|
        p.dirname.mkpath
        p.write(JSON.dump(@data))
      end
    end

    def to_h
      @data
    end

    private

    def path
      filename = [
        AppProfiler.profile_file_prefix.call,
        mode,
        id,
        Socket.gethostname,
      ].compact.join("-") << ".json"

      raise UnsafeFilename if /[^0-9A-Za-z.\-\_]/.match?(filename)

      AppProfiler.profile_root.join(filename)
    end
  end
end
