# frozen_string_literal: true

require "active_support"
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
  end

  autoload :Middleware, "app_profiler/middleware"
  autoload :RequestParameters, "app_profiler/request_parameters"
  autoload :Profiler, "app_profiler/profiler"
  autoload :Profile, "app_profiler/profile"

  mattr_accessor :logger
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
      @@request_profile_header ||= begin # rubocop:disable Style/ClassVars
        profile_header.upcase.gsub("-", "_").prepend("HTTP_")
      end
    end

    def profile_data_header
      @@profile_data_header ||= profile_header.dup << "-Data" # rubocop:disable Style/ClassVars
    end

    def profile_url_formatter=(block)
      @@profile_url_formatter = block # rubocop:disable Style/ClassVars
    end
  end
end
