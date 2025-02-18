# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/class"
require "active_support/core_ext/module"
require "logger"
require "app_profiler/version"

module AppProfiler
  PROFILE_ID_METADATA_KEY = :profile_id
  PROFILE_BACKEND_METADATA_KEY = :profiler

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
    autoload :SpeedscopeViewer, "app_profiler/viewer/speedscope_viewer"
    autoload :FirefoxViewer, "app_profiler/viewer/firefox_viewer"
    autoload :BaseMiddleware, "app_profiler/viewer/base_middleware"
    autoload :SpeedscopeRemoteViewer, "app_profiler/viewer/speedscope_remote_viewer"
    autoload :FirefoxRemoteViewer, "app_profiler/viewer/firefox_remote_viewer"
  end

  autoload(:Middleware, "app_profiler/middleware")
  autoload(:Parameters, "app_profiler/parameters")
  autoload(:RequestParameters, "app_profiler/request_parameters")
  autoload(:BaseProfile, "app_profiler/base_profile")
  autoload :StackprofProfile, "app_profiler/stackprof_profile"
  autoload :VernierProfile, "app_profiler/vernier_profile"
  autoload(:Backend, "app_profiler/backend")
  autoload(:Server, "app_profiler/server")
  autoload(:Sampler, "app_profiler/sampler")
  autoload(:ProfileId, "app_profiler/profile_id")

  mattr_accessor :logger, default: Logger.new($stdout)
  mattr_accessor :root
  mattr_accessor :profile_root

  mattr_accessor :speedscope_host, default: "https://speedscope.app"
  mattr_accessor :autoredirect, default: false
  mattr_reader   :profile_header, default: "X-Profile"
  mattr_accessor :profile_async_header, default: "X-Profile-Async"
  mattr_accessor :context, default: nil
  mattr_reader   :profile_url_formatter, default: DefaultProfileFormatter
  mattr_accessor :storage, default: Storage::FileStorage
  mattr_writer :stackprof_viewer, default: nil
  mattr_writer :vernier_viewer, default: nil
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
  mattr_reader :profile_file_name

  class << self
    attr_reader :otel_instrumentation_enabled

    def deprecator # :nodoc:
      @deprecator ||= ActiveSupport::Deprecation.new("in future releases", "app_profiler")
    end

    def run(*args, backend: nil, **kwargs, &block)
      if backend
        original_backend = self.backend
        self.backend = backend
      end
      profiler.run(*args, **kwargs, &block)
    rescue BackendError => e
      logger.error(
        "[AppProfiler.run] exception #{e} configuring backend #{backend}: #{e.message}",
      )
      yield
    ensure
      self.backend = original_backend if backend
      ProfileId::Current.reset
    end

    def start(*args, backend: nil, **kwargs)
      self.backend = backend if backend
      profiler.start(*args, **kwargs)
    end

    def stop
      profiler.stop
      profiler.results.tap { clear }
    end

    def running?
      @profiler&.running?
    end

    def profiler
      @profiler ||= profiler_backend.new
    end

    def backend=(new_backend)
      return if (new_profiler_backend = backend_for(new_backend)) == profiler_backend

      if running?
        raise BackendError,
          "cannot change backend to #{new_backend} while #{backend} backend is running"
      end

      clear
      @profiler_backend = new_profiler_backend
    end

    def stackprof_viewer
      @@stackprof_viewer ||= Viewer::SpeedscopeViewer # rubocop:disable Style/ClassVars
    end

    def vernier_viewer
      @@vernier_viewer ||= Viewer::FirefoxViewer # rubocop:disable Style/ClassVars
    end

    def profile_file_name=(value)
      raise ArgumentError, "profile_file_name must be a proc" if value && !value.is_a?(Proc)

      @@profile_file_name = value # rubocop:disable Style/ClassVars
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

    def otel_instrumentation_enabled=(value)
      if value
        gem("opentelemetry-instrumentation-rack")
        require("opentelemetry/instrumentation/rack")
      end

      @otel_instrumentation_enabled = value
    end

    def backend_for(backend_name)
      if vernier_supported? &&
          backend_name&.to_sym == AppProfiler::VernierProfile::BACKEND_NAME
        AppProfiler::Backend::VernierBackend
      elsif backend_name&.to_sym == AppProfiler::Backend::StackprofBackend.name
        AppProfiler::Backend::StackprofBackend
      else
        raise BackendError, "unknown backend #{backend_name.inspect}"
      end
    end

    def backend
      profiler_backend.name
    end

    def vernier_supported?
      RUBY_VERSION >= "3.2.1" && defined?(AppProfiler::VernierProfile::BACKEND_NAME)
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

    def viewer
      deprecator.warn("AppProfiler.viewer is deprecated, please use stackprof_viewer instead.")
      stackprof_viewer
    end

    def viewer=(viewer)
      deprecator.warn("AppProfiler.viewer= is deprecated, please use stackprof_viewer= instead.")
      self.stackprof_viewer = viewer
    end

    private

    def profiler_backend
      @profiler_backend ||= Backend::StackprofBackend
    end

    def clear
      profiler.stop if running?
      @profiler = nil
      @profiler_backend = nil
    end
  end

  require "app_profiler/railtie" if defined?(Rails::Railtie)
end
