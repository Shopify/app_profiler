# frozen_string_literal: true

require "rack"

module AppProfiler
  class RequestParameters
    def initialize(request)
      @request = request
    end

    def autoredirect
      query_param("autoredirect") || profile_header_param("autoredirect")
    end

    def async
      query_param("async")
    end

    def backend
      query_param("backend") || profile_header_param("backend") ||
        AppProfiler.backend::NAME
    end

    def valid?
      if mode.blank?
        return false
      end

      return false if backend != AppProfiler::StackprofBackend::NAME && !defined?(AppProfiler::VernierBackend)

      if defined?(AppProfiler::VernierBackend) && backend == AppProfiler::VernierBackend::NAME &&
          !AppProfiler::VernierBackend::AVAILABLE_MODES.include?(mode.to_sym)
        AppProfiler.logger.info("[AppProfiler] unsupported profiling mode=#{mode} for backend #{backend}")
        return false
      elsif backend == AppProfiler::StackprofBackend::NAME &&
          !AppProfiler::StackprofBackend::AVAILABLE_MODES.include?(mode.to_sym)
        AppProfiler.logger.info("[AppProfiler] unsupported profiling mode=#{mode} for backend #{backend}")
        return false
      end

      if interval.to_i < Parameters::MIN_INTERVALS[mode.to_s]
        return false
      end

      true
    end

    def to_h
      {
        mode: mode.to_sym,
        interval: interval.to_i,
        ignore_gc: !!ignore_gc,
        metadata: {
          id: request_id,
          context: context,
        },
      }
    end

    private

    def mode
      query_param("profile") || profile_header_param("mode")
    end

    def ignore_gc
      query_param("ignore_gc") || profile_header_param("ignore_gc")
    end

    def interval
      query_param("interval") || profile_header_param("interval") || Parameters::DEFAULT_INTERVALS[mode.to_s]
    end

    def request_id
      header("HTTP_X_REQUEST_ID")
    end

    def context
      profile_header_param("context").presence || AppProfiler.context
    end

    def profile_header_param(name)
      query_parser.parse_nested_query(header(profile_header), ";")[name]
    rescue Rack::QueryParser::ParameterTypeError, RangeError
      nil
    end

    def query_param(name)
      @request.GET[name]
    rescue Rack::QueryParser::ParameterTypeError, RangeError
      nil
    end

    def header(name)
      return unless @request.has_header?(name)

      @request.get_header(name)
    end

    def query_parser
      Rack::Utils.default_query_parser
    end

    def profile_header
      AppProfiler.request_profile_header
    end
  end
end
