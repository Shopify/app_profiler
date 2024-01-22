# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class RequestParametersTest < TestCase
    test "#valid? returns false when mode is not present" do
      AppProfiler.logger.expects(:info).never

      assert_not_predicate(request_params, :valid?)
    end

    test "#valid? returns false when mode is unsupported" do
      AppProfiler.logger.expects(:info).with { |value| value =~ /unsupported profiling mode=unsupported/ }
      params = request_params(headers: { AppProfiler.request_profile_header => "mode=unsupported" })

      assert_not_predicate(params, :valid?)
    end

    test "#valid? returns false when interval is less than allowed" do
      AppProfiler.logger.expects(:info).never
      AppProfiler::StackprofBackend::AVAILABLE_MODES.each do |mode|
        interval = AppProfiler::Parameters::MIN_INTERVALS[mode.to_s] - 1
        params = request_params(headers: {
          AppProfiler.request_profile_header => "mode=#{mode};interval=#{interval}",
        })

        assert_not_predicate(params, :valid?)
      end
    end

    test "#context is AppProfiler.context by default" do
      with_context("test-context") do
        AppProfiler.logger.expects(:info).never
        params = request_params(headers: { AppProfiler.request_profile_header => "mode=cpu" })

        assert_equal(AppProfiler.context, params.to_h[:metadata][:context])
        assert_predicate(params, :valid?)
      end
    end

    test "#context is AppProfiler.context when passed as empty string" do
      with_context("test-context") do
        AppProfiler.logger.expects(:info).never
        params = request_params(headers: { AppProfiler.request_profile_header => "mode=cpu;context=;" })

        assert_equal(AppProfiler.context, params.to_h[:metadata][:context])
        assert_predicate(params, :valid?)
      end
    end

    test "#to_h return correct hash when request parameters are ok" do
      AppProfiler::StackprofBackend::AVAILABLE_MODES.each do |mode|
        interval = AppProfiler::Parameters::DEFAULT_INTERVALS[mode.to_s]
        params = request_params(headers: {
          AppProfiler.request_profile_header => "mode=#{mode};interval=#{interval};context=test;ignore_gc=1",
          "HTTP_X_REQUEST_ID" => "123",
        })

        assert_equal(
          { mode: mode.to_sym, interval: interval.to_i, ignore_gc: true, metadata: { id: "123", context: "test" } },
          params.to_h
        )
        assert_predicate(params, :valid?)
      end
    end

    private

    def request_params(headers: {})
      RequestParameters.new(mock_request(headers))
    end

    def mock_request(headers, path: "/")
      Rack::Request.new(
        Rack::MockRequest.env_for("https://example.com#{path}", headers)
      )
    end
  end
end
