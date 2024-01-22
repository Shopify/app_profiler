# frozen_string_literal: true

require "rack"
require "app_profiler/middleware/base_action"
require "app_profiler/middleware/upload_action"
require "app_profiler/middleware/view_action"

module AppProfiler
  class Middleware
    class_attribute :action,   default: UploadAction
    class_attribute :disabled, default: false

    def initialize(app)
      @app = app
    end

    def call(env, params = AppProfiler::RequestParameters.new(Rack::Request.new(env)))
      profile(env, params) do
        @app.call(env)
      end
    end

    private

    def profile(env, params)
      response = nil
      app_profiler_params = profile_params(params)

      return yield unless app_profiler_params

      params_hash = app_profiler_params.to_h
      return yield unless before_profile(env, params_hash)

      profile = AppProfiler.run(**params_hash) do
        response = yield
      end

      return response unless profile && after_profile(env, profile)

      action.call(
        profile,
        response: response,
        autoredirect: app_profiler_params.autoredirect,
        async: app_profiler_params.async,
      )

      response
    end

    def profile_params(params)
      return params if params.valid?
      return unless AppProfiler.profile_sampler_enabled

      AppProfiler::Sampler.profile_params(params, AppProfiler.profile_sampler_config)
    end

    def before_profile(_env, _params)
      true
    end

    def after_profile(_env, _profile)
      true
    end
  end
end
