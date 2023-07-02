# frozen_string_literal: true

require "rails"

module AppProfiler
  class Railtie < Rails::Railtie
    config.app_profiler = ActiveSupport::OrderedOptions.new
    config.app_profiler.profile_url_formatter = DefaultProfileFormatter

    initializer "app_profiler.configs" do |app|
      puts "ENABLED #{app.config.app_profiler.server_enabled}"
      AppProfiler.logger = app.config.app_profiler.logger || Rails.logger
      AppProfiler.root = app.config.app_profiler.root || Rails.root
      AppProfiler.storage = app.config.app_profiler.storage || Storage::FileStorage
      AppProfiler.viewer = app.config.app_profiler.viewer || Viewer::SpeedscopeViewer
      AppProfiler.storage.bucket_name = app.config.app_profiler.storage_bucket_name || "profiles"
      AppProfiler.storage.credentials = app.config.app_profiler.storage_credentials || {}
      AppProfiler.middleware = app.config.app_profiler.middleware || Middleware
      AppProfiler.middleware.action = app.config.app_profiler.middleware_action || default_middleware_action
      AppProfiler.middleware.disabled = app.config.app_profiler.middleware_disabled || false
      AppProfiler.autoredirect = app.config.app_profiler.autoredirect || false
      AppProfiler.speedscope_host = app.config.app_profiler.speedscope_host || ENV.fetch(
        "APP_PROFILER_SPEEDSCOPE_URL", "https://speedscope.app"
      )
      AppProfiler.profile_header = app.config.app_profiler.profile_header || "X-Profile"
      AppProfiler.profile_async_header = app.config.app_profiler.profile_async_header || "X-Profile-Async"
      AppProfiler.profile_root = app.config.app_profiler.profile_root || Rails.root.join(
        "tmp", "app_profiler"
      )
      AppProfiler.context = app.config.app_profiler.context || Rails.env
      AppProfiler.profile_url_formatter = app.config.app_profiler.profile_url_formatter
      AppProfiler.upload_queue_max_length = app.config.upload_queue_max_length || 10
      AppProfiler.upload_queue_interval_secs = app.config.upload_queue_interval_secs || 5
    end

    initializer "app_profiler.add_middleware" do |app|
      unless AppProfiler.middleware.disabled
        if AppProfiler.viewer == Viewer::SpeedscopeRemoteViewer
          app.middleware.insert_before(0, Viewer::SpeedscopeRemoteViewer::Middleware)
        end
        app.middleware.insert_before(0, AppProfiler.middleware)
        ActiveSupport::ForkTracker.after_fork do
          AppProfiler::Middleware::UploadAction.start_process_queue_thread
        end
      end
    end

    initializer "app_profiler.enable_server" do
      if AppProfiler.server.enabled
        AppProfiler::Server.start(AppProfiler.logger)
        ActiveSupport::ForkTracker.after_fork do
          AppProfiler::Server.start(AppProfiler.logger)
        end
      end
    end

    initializer "app_profiler.enable_server" do
      puts "Starting server #{AppProfiler.server.enabled}"
      AppProfiler::Server.start! if AppProfiler.server.enabled
      puts "Port #{AppProfiler::Server.port?}"
    end

    private

    def default_middleware_action
      if Rails.env.development?
        Middleware::ViewAction
      else
        Middleware::UploadAction
      end
    end

    def default_appprofiler_transport
      if Rails.env.development?
        # default to TCP server in development so that if wanted users are able to target
        # the server with speedscope
        AppProfiler::Server::TRANSPORT_TCP
      else
        AppProfiler::Server::TRANSPORT_UNIX
      end
    end
  end
end
