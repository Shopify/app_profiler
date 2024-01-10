# frozen_string_literal: true

module AppProfiler
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
      # FIXME: we don't delete here, that is causing a segfault in vernier. Divergent behaviour from stackprof,
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

    def view(params = {})
      # HACK: - we should have a better way of toggling this
      if defined?(AppProfiler::VernierBackend) &&
          AppProfiler.profiler_backend == AppProfiler::VernierBackend
        AppProfiler.viewer = Viewer::FirefoxProfileRemoteViewer
      end

      AppProfiler.viewer.view(self, **params)
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

  class StackprofProfile < Profile
    delegate :[], to: :@data

    def file
      @file ||= path.tap do |p|
        p.dirname.mkpath
        p.write(JSON.dump(@data))
      end
    end

    def to_h
      @data
    end

    def valid?
      mode.present?
    end

    def mode
      @data[:mode]
    end
  end

  class VernierProfile < Profile
    delegate :[], to: :@meta

    attr_reader :data

    def initialize(data, id: nil, context: nil)
      @meta = data.meta
      super
    end

    # https://github.com/jhawthorn/vernier/blob/main/lib/vernier/result.rb#L27-L29
    def file
      @file ||= path.tap do |p|
        p.dirname.mkpath
        @data.write(out: p)
      end
    end

    def valid?
      !@data.nil?
    end

    def to_h
      nil
    end

    def mode
      @meta[:mode]
    end
  end
end
