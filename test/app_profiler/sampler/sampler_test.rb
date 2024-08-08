# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Sampler
    class SamplerTest < TestCase
      test "does not sample when sample_rate is zero" do
        config = Config.new(
          sample_rate: 0,
        )
        request = RequestParameters.new(Rack::Request.new({ "PATH_INFO" => "/" }))
        assert_nil(AppProfiler::Sampler.profile_params(request, config))
      end

      test "does not sample when rand is greater than sample_rate" do
        config = Config.new(
          sample_rate: 0.5,
        )
        Kernel.stubs(:rand).returns(0.6)
        request = RequestParameters.new(Rack::Request.new({ "PATH_INFO" => "/" }))
        assert_nil(Sampler.profile_params(request, config))
      end

      test "only path specified in the config is profiled" do
        Kernel.stubs(:rand).returns(0.1)
        config = Config.new(
          sample_rate: 1.0,
          paths: ["/foo"],
        )

        request = RequestParameters.new(Rack::Request.new({ "PATH_INFO" => "/foo" }))
        assert_equal(:stackprof, Sampler.profile_params(request, config).backend)

        request = RequestParameters.new(Rack::Request.new({ "PATH_INFO" => "/bar" }))
        assert_nil(Sampler.profile_params(request, config))
      end

      test "mixed backend probabilities" do
        skip("Vernier not supported") unless AppProfiler.vernier_supported?

        test_cases = [
          {
            sample_rate: 0.9,
            vernier_probability: 0.2,
            stackprof_probability: 0.8,
            expected_backend: :vernier,
            rand: 0.1,
          },
          {
            sample_rate: 0.9,
            vernier_probability: 0.2,
            stackprof_probability: 0.8,
            expected_backend: :stackprof,
            rand: 0.8,
          },
          {
            sample_rate: 0.9,
            vernier_probability: 0.51,
            stackprof_probability: 0.49,
            expected_backend: :vernier,
            rand: 0.51,
          },
          {
            sample_rate: 0.9,
            vernier_probability: 0.51,
            stackprof_probability: 0.49,
            expected_backend: :stackprof,
            rand: 0.49,
          },

        ]

        test_cases.each do |test_case|
          Kernel.stubs(:rand).returns(test_case[:rand])
          config = Config.new(
            sample_rate: test_case[:sample_rate],
            backends_config: {
              stackprof: StackprofConfig.new,
              vernier: VernierConfig.new,
            },
            backends_probability: {
              stackprof: test_case[:stackprof_probability],
              vernier: test_case[:vernier_probability],
            },
          )
          request = RequestParameters.new(Rack::Request.new({ "PATH_INFO" => "/" }))
          assert_equal(test_case[:expected_backend], AppProfiler::Sampler.profile_params(request, config).backend)
        end
      end
    end
  end
end
