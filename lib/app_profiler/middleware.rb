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

    def call(env)
      profile(env) do
        @app.call(env)
      end
    end

    private

    def profile(env)
      params   = AppProfiler::RequestParameters.new(Rack::Request.new(env))
      response = nil

      return yield unless params.valid?

      params_hash = params.to_h

      return yield unless before_profile(env, params_hash)

      profile = AppProfiler.run(params_hash) do
        response = yield
      end

      return response unless profile && after_profile(env, profile)

      action.call(
        profile,
        response: response,
        autoredirect: params.autoredirect,
      )

      response
    end

    def before_profile(_env, _params)
      true
    end

    def after_profile(_env, _profile)
      true
    end
  end
end
