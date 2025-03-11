# frozen_string_literal: true

require "rack"
require "app_profiler/middleware/base_action"
require "app_profiler/middleware/upload_action"
require "app_profiler/middleware/view_action"

module AppProfiler
  class Middleware
    OTEL_PROFILE_ID = "profile.id"
    OTEL_PROFILE_BACKEND = "profile.profiler"
    OTEL_PROFILE_MODE = "profile.mode"
    OTEL_PROFILE_CONTEXT = "profile.context"
    OTEL_SERVICE_NAME_KEY = "service.name"

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

      add_otel_instrumentation(env, params_hash) if AppProfiler.otel_instrumentation_enabled

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

    def add_otel_instrumentation(env, params)
      rack_span = OpenTelemetry::Instrumentation::Rack.current_span
      return unless rack_span.recording?

      metadata = params[:metadata]
      profile_id = if metadata[:id].present?
        metadata[:id]
      else
        AppProfiler::ProfileId.current
      end

      attributes = {
        OTEL_PROFILE_ID => profile_id,
        OTEL_PROFILE_BACKEND => params[:backend].to_s,
        OTEL_PROFILE_MODE => params[:mode].to_s,
        OTEL_PROFILE_CONTEXT => AppProfiler.context,
      }

      metadata = params[:metadata]

      # https://github.com/open-telemetry/opentelemetry-ruby/blob/aacd8c8e264b110507c2a733dcc5309ca26aac66/sdk/lib/opentelemetry/sdk/resources/resource.rb#L91-L92
      rack_span.resource.attribute_enumerator.each do |key, value|
        if key == OTEL_SERVICE_NAME_KEY
          metadata[:service_name] = value
          break
        end
      end

      rack_span.add_attributes(attributes)
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
