# frozen_string_literal: true

require "active_support/core_ext/class"
require "active_support/core_ext/module"
require "logger"
require "app_profiler/version"

module AppProfiler
  class ConfigurationError < StandardError
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
    autoload :SpeedscopeRemoteViewer, "app_profiler/viewer/speedscope_remote_viewer"
  end

  require "app_profiler/middleware"
  require "app_profiler/parameters"
  require "app_profiler/request_parameters"
  require "app_profiler/profile"
  require "app_profiler/backend"
  require "app_profiler/server"

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
  mattr_accessor :profiler_backend, default: AppProfiler::Backend::Stackprof

  mattr_accessor :storage, default: Storage::FileStorage
  mattr_accessor :viewer, default: Viewer::SpeedscopeViewer
  mattr_accessor :middleware, default: Middleware
  mattr_accessor :server, default: Server
  mattr_accessor :upload_queue_max_length, default: 10
  mattr_accessor :upload_queue_interval_secs, default: 5
  mattr_accessor :profile_file_prefix, default: DefaultProfilePrefix

  class << self
    def run(*args, &block)

      profiler_backend.run(*args, &block)
    end

    def start(*args)
      profiler_backend.start(*args)
    end

    def stop
      profiler_backend.stop
    end

    def results
      profiler_backend.results
    end

    def running?
      profiler_backend.running?
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

    def profile_url(upload)
      return unless AppProfiler.profile_url_formatter

      AppProfiler.profile_url_formatter.call(upload)
    end
  end

  require "app_profiler/railtie" if defined?(Rails::Railtie)
end
