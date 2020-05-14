# frozen_string_literal: true

require "rails"

module AppProfiler
  class Railtie < Rails::Railtie
    config.app_profiler = ActiveSupport::OrderedOptions.new

    initializer "app_profiler.configs" do |app|
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
      AppProfiler.profile_root = app.config.app_profiler.profile_root || Rails.root.join(
        "tmp", "app_profiler"
      )
      AppProfiler.context = app.config.app_profiler.context || Rails.env
      AppProfiler.request_authorization_required = !(Rails.env.development? || Rails.env.test?)
    end

    initializer "app_profiler.add_middleware" do |app|
      unless AppProfiler.middleware.disabled
        app.middleware.insert_before(0, AppProfiler.middleware)
      end
    end

    private

    def default_middleware_action
      if Rails.env.development?
        Middleware::ViewAction
      else
        Middleware::UploadAction
      end
    end
  end
end
