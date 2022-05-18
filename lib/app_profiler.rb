# frozen_string_literal: true

require "active_support/core_ext/class"
require "active_support/core_ext/module"
require "logger"
require "app_profiler/version"
require "app_profiler/railtie" if defined?(Rails::Railtie)

module AppProfiler
  class ConfigurationError < StandardError
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
  require "app_profiler/request_parameters"
  require "app_profiler/profiler"
  require "app_profiler/profile"
  require "app_profiler/server"

  mattr_accessor :logger, default: Logger.new($stdout)
  mattr_accessor :root
  mattr_accessor :profile_root

  mattr_accessor :speedscope_host, default: "https://speedscope.app"
  mattr_accessor :autoredirect, default: false
  mattr_reader   :profile_header, default: "X-Profile"
  mattr_accessor :context, default: nil
  mattr_reader   :profile_url_formatter, default: nil

  mattr_accessor :storage, default: Storage::FileStorage
  mattr_accessor :viewer, default: Viewer::SpeedscopeViewer
  mattr_accessor :middleware, default: Middleware

  class << self
    def run(*args, &block)
      Profiler.run(*args, &block)
    end

    def start(*args)
      Profiler.start(*args)
    end

    def stop
      Profiler.stop
      Profiler.results
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
  end
end
