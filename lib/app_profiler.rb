# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/class"
require "active_support/core_ext/module"
require "logger"
require "app_profiler/version"

module AppProfiler
  class ConfigurationError < StandardError
  end

  class BackendError < StandardError
  end

  DefaultProfileFormatter = proc do |upload|
    "#{AppProfiler.speedscope_host}#profileURL=#{upload.url}"
  end

  DefaultProfilePrefix = proc do
    Time.zone.now.strftime("%Y%m%d-%H%M%S")
  end

  module Storage
    autoload :BaseStorage, "app_profiler/storage/base_storage"
    autoload :FileStorage, "app_profiler/storage/file_storage"
    autoload :GoogleCloudStorage, "app_profiler/storage/google_cloud_storage"
  end

  module Viewer
    autoload :BaseViewer, "app_profiler/viewer/base_viewer"
    autoload :SpeedscopeViewer, "app_profiler/viewer/speedscope"
    autoload :SpeedscopeRemoteViewer, "app_profiler/viewer/remote/speedscope"
    autoload :FirefoxRemoteViewer, "app_profiler/viewer/remote/firefox"
  end

  require "app_profiler/middleware"
  require "app_profiler/parameters"
  require "app_profiler/request_parameters"
  require "app_profiler/profile"
  require "app_profiler/backend"
  require "app_profiler/server"
  require "app_profiler/sampler"

  mattr_accessor :logger, default: Logger.new($stdout)
  mattr_accessor :root
  mattr_accessor :profile_root

  mattr_accessor :speedscope_host, default: "https://speedscope.app"
  mattr_accessor :autoredirect, default: false
  mattr_reader   :profile_header, default: "X-Profile"
  mattr_accessor :profile_async_header, default: "X-Profile-Async"
  mattr_accessor :context, default: nil
  mattr_reader   :profile_url_formatter,
    default: DefaultProfileFormatter

  mattr_accessor :gecko_viewer_package, default: "https://github.com/tenderlove/profiler#v0.0.2"
  mattr_accessor :storage, default: Storage::FileStorage
  mattr_accessor :viewer, default: Viewer::SpeedscopeViewer # DEPRECATED
  mattr_accessor :speedscope_viewer, default: Viewer::SpeedscopeViewer
  mattr_accessor :middleware, default: Middleware
  mattr_accessor :server, default: Server
  mattr_accessor :upload_queue_max_length, default: 10
  mattr_accessor :upload_queue_interval_secs, default: 5
  mattr_accessor :profile_file_prefix, default: DefaultProfilePrefix
  mattr_reader :profile_enqueue_success, default: nil
  mattr_reader :profile_enqueue_failure, default: nil
  mattr_reader :after_process_queue, default: nil
  mattr_accessor :forward_metadata_on_upload, default: false

  mattr_accessor :profile_sampler_config

  class << self
    def run(*args, backend: nil, **kwargs, &block)
      orig_backend = self.backend
      begin
        self.backend = backend if backend
        profiler.run(*args, **kwargs, &block)
      rescue BackendError => e
        logger.error(
          "[AppProfiler.run] exception #{e} configuring backend #{backend}: #{e.message}",
        )
        yield
      end
    ensure
      AppProfiler.backend = orig_backend
    end

    def start(*args)
      profiler.start(*args)
    end

    def stop
      profiler.stop
      profiler.results
    end

    def running?
      @backend&.running?
    end

    def profiler
      backend
      @backend ||= @profiler_backend.new
    end

    def backend=(new_backend)
      return if new_backend == backend

      new_profiler_backend = backend_for(new_backend)

      if running?
        raise BackendError,
          "cannot change backend to #{new_backend} while #{backend} backend is running"
      end

      return if @profiler_backend == new_profiler_backend

      clear
      @profiler_backend = new_profiler_backend
    end

    def profile_sampler_enabled=(value)
      if value.is_a?(Proc)
        raise ArgumentError,
          "profile_sampler_enabled must be a proc or a lambda that accepts no argument" if value.arity != 0
      else
        raise ArgumentError, "Must be TrueClass or FalseClass" unless [TrueClass, FalseClass].include?(value.class)
      end

      @profile_sampler_enabled = value
    end

    def profile_sampler_enabled
      return false unless defined?(@profile_sampler_enabled)

      @profile_sampler_enabled.is_a?(Proc) ? @profile_sampler_enabled.call : @profile_sampler_enabled
    rescue => e
      logger.error(
        "[AppProfiler.profile_sampler_enabled] exception: #{e}, message: #{e.message}",
      )
      false
    end

    def backend_for(backend_name)
      if vernier_supported? &&
          backend_name == AppProfiler::Backend::VernierBackend.name
        AppProfiler::Backend::VernierBackend
      elsif backend_name == AppProfiler::Backend::StackprofBackend.name
        AppProfiler::Backend::StackprofBackend
      else
        raise BackendError, "unknown backend #{backend_name}"
      end
    end

    def backend
      @profiler_backend ||= Backend::StackprofBackend
      @profiler_backend.name
    end

    def vernier_supported?
      defined?(AppProfiler::Backend::VernierBackend.name)
    end

    def profile_header=(profile_header)
      @@profile_header = profile_header # rubocop:disable Style/ClassVars
      @@request_profile_header = nil    # rubocop:disable Style/ClassVars
      @@profile_data_header = nil       # rubocop:disable Style/ClassVars
    end

    def request_profile_header
      @@request_profile_header ||= profile_header.upcase.tr("-", "_").prepend("HTTP_") # rubocop:disable Style/ClassVars
    end

    def profile_data_header
      @@profile_data_header ||= profile_header.dup << "-Data" # rubocop:disable Style/ClassVars
    end

    def profile_url_formatter=(block)
      @@profile_url_formatter = block # rubocop:disable Style/ClassVars
    end

    def profile_enqueue_success=(handler)
      if handler && (!handler.is_a?(Proc) || (handler.lambda? && handler.arity != 0))
        raise ArgumentError, "profile_enqueue_success must be proc or a lambda that accepts no argument"
      end

      @@profile_enqueue_success = handler # rubocop:disable Style/ClassVars
    end

    def profile_enqueue_failure=(handler)
      if handler && (!handler.is_a?(Proc) || (handler.lambda? && handler.arity != 1))
        raise ArgumentError, "profile_enqueue_failure must be a proc or a lambda that accepts one argument"
      end

      @@profile_enqueue_failure = handler # rubocop:disable Style/ClassVars
    end

    def after_process_queue=(handler)
      if handler && (!handler.is_a?(Proc) || (handler.lambda? && handler.arity != 2))
        raise ArgumentError, "after_process_queue must be a proc or a lambda that accepts two arguments"
      end

      @@after_process_queue = handler # rubocop:disable Style/ClassVars
    end

    def profile_url(upload)
      return unless AppProfiler.profile_url_formatter

      AppProfiler.profile_url_formatter.call(upload)
    end

    private

    def clear
      @backend.stop if @backend&.running?
      @backend = nil
    end

    # DEPRECATIONS
    def viewer
      ActiveSupport::Deprecation.warn("viewer is deprecated, use speedscope_viewer instead")
      @viewer
    end

    def viewer=(viewer)
      ActiveSupport::Deprecation.warn("viewer= is deprecated, use speedscope_viewer= instead")
      @viewer = viewer
    end
  end

  require "app_profiler/railtie" if defined?(Rails::Railtie)
end
