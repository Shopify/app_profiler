# frozen_string_literal: true

require "test_helper"
require "opentelemetry/instrumentation/rack"

module AppProfiler
  class MiddlewareTest < TestCase
    test "requests are not profiled by default" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        call_middleware(middleware, mock_request_env)
      end
    end

    test "profiles are uploaded when request is profiled" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
        end
      end
    end

    test "otel instrumentation works" do
      with_otel_instrumentation_enabled do
        AppProfiler::ProfileId.stubs(:current).returns("1")
        OpenTelemetry::Instrumentation::Rack.current_span.stubs(:recording?).returns(true)
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            OpenTelemetry::Instrumentation::Rack.current_span.expects(:add_attributes).with do |attributes|
              assert_equal(attributes[AppProfiler::Middleware::OTEL_PROFILE_ID], "1")
              assert_equal(attributes[AppProfiler::Middleware::OTEL_PROFILE_BACKEND], "stackprof")
              assert_equal(attributes[AppProfiler::Middleware::OTEL_PROFILE_MODE], "cpu")
            end
            call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
          end
        end
      end
    end

    test "otel attributes are not added when span is not sampled" do
      with_otel_instrumentation_enabled do
        OpenTelemetry::Instrumentation::Rack.current_span.stubs(:recording?).returns(false)
        OpenTelemetry::Instrumentation::Rack.current_span.expects(:add_attributes).never

        call_middleware(AppProfiler::Middleware.new(app_env), mock_request_env(path: "/?profile=cpu"))
      end
    end

    AppProfiler::Backend::StackprofBackend::AVAILABLE_MODES.each do |mode|
      test "profile mode #{mode} is supported by stackprof backend" do
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            call_middleware(middleware, mock_request_env(path: "/?profile=#{mode}"))
          end
        end
      end
    end

    AppProfiler::Backend::VernierBackend::AVAILABLE_MODES.each do |mode|
      test "profile mode #{mode} is supported by vernier backend" do
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            call_middleware(middleware, mock_request_env(path: "/?profile=#{mode}&backend=vernier"))
          end
        end
      end
    end

    test "the backend can be toggled between requests" do
      assert_profiles_dumped(3) do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          with_profile_id_reset do
            call_middleware(middleware, mock_request_env(path: "/?profile=wall&backend=stackprof"))
          end
        end

        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          with_profile_id_reset do
            call_middleware(middleware, mock_request_env(path: "/?profile=wall&backend=vernier"))
          end
        end

        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          with_profile_id_reset do
            call_middleware(middleware, mock_request_env(path: "/?profile=wall&backend=stackprof"))
          end
        end

        json_profiles = tmp_profiles.select { |p| p.to_s =~ /#{AppProfiler::StackprofProfile::FILE_EXTENSION}$/ }
        vernier_profiles = tmp_profiles.select { |p| p.to_s =~ /#{AppProfiler::VernierProfile::FILE_EXTENSION}$/ }
        stackprof_profiles = json_profiles - vernier_profiles
        assert_equal(2, stackprof_profiles.size)
        assert_equal(1, vernier_profiles.size)
      end
    end

    test "profile interval is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, mock_request_env(path: "/?profile=cpu&interval=2000"))
        end
      end
    end

    test "interval without profile mode will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        call_middleware(middleware, mock_request_env(path: "/?interval=2000"))
      end
    end

    test "autoredirect with profile is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, mock_request_env(path: "/?profile=cpu&autoredirect=1"))
        end
      end
    end

    test "autoredirect config with profile is supported" do
      AppProfiler.autoredirect = true
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
        end
      end
      AppProfiler.autoredirect = false
    end

    test "autoredirect without profile will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        call_middleware(middleware, mock_request_env(path: "/?autoredirect=1"))
      end
    end

    test "ignore_gc option is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, mock_request_env(path: "/?profile=cpu&ignore_gc=1"))
        end
      end
    end

    test "ignore_gc option through headers is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu;interval=2000;ignore_gc=1" }
          call_middleware(middleware, mock_request_env(opt: opt))
        end
      end
    end

    test "invalid profile mode will not profile" do
      assert_profiles_dumped(0) do
        AppProfiler.logger.expects(:info).with { |value| value =~ /unsupported profiling mode=hello/ }
        middleware = AppProfiler::Middleware.new(app_env)
        call_middleware(middleware, mock_request_env(path: "/?profile=hello"))
      end
    end

    test "invalid profile interval will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        call_middleware(middleware, mock_request_env(path: "/?profile=cpu&interval=1"))
      end
    end

    test "profiles will not be generated when query string exceeds the parser depth limit" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        path = "/?profile=cpu&contact#{"[child]" * (Rack::Utils.param_depth_limit + 1)}=value"
        call_middleware(middleware, mock_request_env(path: path))
      end
    end

    test "profile upload error prints logs" do
      AppProfiler.stubs(:storage).returns(MockStorage)
      AppProfiler.logger.expects(:info).with { |value| value =~ /failed to upload profile/ }
      middleware = AppProfiler::Middleware.new(app_env)
      AppProfiler.storage.stubs(:upload).raises(StandardError, "upload error")
      response = call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
      assert_nil(response[1][AppProfiler.profile_header.downcase])
      assert_nil(response[1][AppProfiler.profile_data_header.downcase])
    end

    test "profiles are uploaded when request is profiled through headers" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu" }
          call_middleware(middleware, mock_request_env(opt: opt))
        end
      end
    end

    test "nil formatter omits profile and redirect headers" do
      old_storage = AppProfiler.storage
      old_formatter = AppProfiler.profile_url_formatter
      AppProfiler.storage = MockStorage
      AppProfiler.profile_url_formatter = nil

      assert_profiles_dumped do
        middleware = AppProfiler::Middleware.new(app_env)
        status, headers, body = call_middleware(
          middleware,
          mock_request_env(path: "/?profile=cpu&autoredirect=1"),
        )

        assert_equal(200, status)
        assert_equal(["OK"], body)
        assert_equal("/profile/file.json", headers["x-profile-data"])
        refute(headers.key?("x-profile"))
        refute(headers.key?("location"))
      end
    ensure
      AppProfiler.storage = old_storage
      AppProfiler.profile_url_formatter = old_formatter
    end

    test "custom profile headers use lowercase response keys" do
      old_profile_header = AppProfiler.profile_header
      AppProfiler.profile_header = "X-Custom-Profile"
      expected_profile_url = AppProfiler.profile_url(MockStorage::FileInfo.new("/profile/file.json"))
      response = nil

      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          response = call_middleware(
            middleware,
            mock_request_env(opt: { "HTTP_X_CUSTOM_PROFILE" => "mode=cpu" }),
          )
        end
      end

      assert_equal(expected_profile_url, response[1]["x-custom-profile"])
      assert_equal("/profile/file.json", response[1]["x-custom-profile-data"])
    ensure
      AppProfiler.profile_header = old_profile_header
    end

    AppProfiler::Backend::StackprofBackend::AVAILABLE_MODES.each do |mode|
      test "profile mode #{mode} through headers is supported" do
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            opt = { AppProfiler.request_profile_header => "mode=#{mode}" }
            call_middleware(middleware, mock_request_env(opt: opt))
          end
        end
      end
    end

    AppProfiler::Backend::VernierBackend::AVAILABLE_MODES.each do |mode|
      test "profile mode #{mode} is supported through headers by vernier backend" do
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            opt = { AppProfiler.request_profile_header => "mode=#{mode};backend=vernier" }
            call_middleware(middleware, mock_request_env(opt: opt))
          end
        end
      end
    end

    test "profile interval through headers is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu;interval=2000" }
          call_middleware(middleware, mock_request_env(opt: opt))
        end
      end
    end

    test "autoredirect with profile through headers is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu;autoredirect=1" }
          call_middleware(middleware, mock_request_env(opt: opt))
        end
      end
    end

    test "autoredirect config with profile through headers is supported" do
      AppProfiler.autoredirect = true
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu" }
          call_middleware(middleware, mock_request_env(opt: opt))
        end
      end
      AppProfiler.autoredirect = false
    end

    test "invalid profile mode in headers will not profile" do
      assert_profiles_dumped(0) do
        AppProfiler.logger.expects(:info).with { |value| value =~ /unsupported profiling mode=hello/ }
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "mode=hello" }
        call_middleware(middleware, mock_request_env(opt: opt))
      end
    end

    test "invalid profile interval in headers will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "mode=cpu;interval=1" }
        call_middleware(middleware, mock_request_env(opt: opt))
      end
    end

    test "headers using & will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "mode=cpu&interval=1" }
        call_middleware(middleware, mock_request_env(opt: opt))
      end
    end

    test "invalid profile headers will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "helloworld" }
        call_middleware(middleware, mock_request_env(opt: opt))
      end
    end

    test "invalid profile will not be uploaded" do
      AppProfiler.expects(:run).yields.returns(nil)
      AppProfiler.middleware.action.expects(:call).never
      middleware = AppProfiler::Middleware.new(app_env)
      opt = { AppProfiler.request_profile_header => "mode=cpu;interval=2000" }
      call_middleware(middleware, mock_request_env(opt: opt))
    end

    test "should not profile if #before_profile returns false" do
      AppProfiler.expects(:run).never
      AppProfiler.middleware.any_instance.stubs(:before_profile).returns(false)

      middleware = AppProfiler::Middleware.new(app_env)
      call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
    end

    test "should not upload if #after_profile returns false" do
      AppProfiler.expects(:run).yields.returns({})
      AppProfiler.middleware.action.expects(:call).never
      AppProfiler.middleware.any_instance.stubs(:after_profile).returns(false)

      middleware = AppProfiler::Middleware.new(app_env)
      call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
    end

    test "#before_profile called with env and profiling params" do
      request_env = mock_request_env(path: "/?profile=cpu")
      AppProfiler.middleware.any_instance.expects(:before_profile).with do |env, params|
        request_env == env && params.is_a?(Hash)
      end.returns(false)
      middleware = AppProfiler::Middleware.new(app_env)
      call_middleware(middleware, request_env)
    end

    test "#after_profile called with env and profile data" do
      request_env = mock_request_env(path: "/?profile=cpu")
      AppProfiler.middleware.any_instance.expects(:after_profile).with do |env, profile|
        request_env == env && profile.is_a?(AppProfiler::BaseProfile)
      end.returns(false)
      middleware = AppProfiler::Middleware.new(app_env)
      call_middleware(middleware, request_env)
    end

    test "should pass modified params to Profiler" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          request_env = mock_request_env(path: "/?profile=cpu")

          AppProfiler.middleware.any_instance.expects(:before_profile).with do |env, params|
            return false unless request_env == env && params.is_a?(Hash)

            params[:metadata][:test_key] = "test_value"
            true
          end.returns(true)

          AppProfiler.middleware.any_instance.expects(:after_profile).with do |env, profile|
            return false unless request_env == env && profile.is_a?(AppProfiler::BaseProfile)

            profile.metadata[:test_key] == "test_value"
          end.returns(true)

          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, request_env)
        end
      end
    end

    test "profiles are not uploaded synchronously when async is requested" do
      old_storage = AppProfiler.storage
      old_async_header = AppProfiler.profile_async_header
      AppProfiler.storage = AppProfiler::Storage::GoogleCloudStorage
      AppProfiler.profile_async_header = "X-Custom-Async"
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        response = call_middleware(middleware, mock_request_env(path: "/?profile=cpu&async=true"))
        assert_equal("true", response[1]["x-custom-async"])
      end
    ensure
      reset_process_queue_thread # kill the background thread and reset the queue
      AppProfiler.storage = old_storage
      AppProfiler.profile_async_header = old_async_header
    end

    class CustomMiddleware < AppProfiler::Middleware
      def call(env)
        super(env, AppProfiler::Parameters.new)
      end
    end

    test "subclassing allows passing custom parameters" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = CustomMiddleware.new(app_env)
          call_middleware(middleware, mock_request_env)
        end
      end
    end

    test "request is sampled" do
      with_profile_sampler_enabled do
        with_google_cloud_storage do
          AppProfiler.profile_sampler_config = AppProfiler::Sampler::Config.new(
            sample_rate: 1.0,
            targets: ["/"],
          )

          assert_profiles_dumped(0) do
            middleware = AppProfiler::Middleware.new(app_env)
            response = call_middleware(middleware, mock_request_env(path: "/"))
            assert(response[1]["x-profile-async"])
          end
        end
      end
    end

    test "request is not sampled when sampler is not enabled" do
      with_google_cloud_storage do
        AppProfiler.profile_sampler_config = AppProfiler::Sampler::Config.new(sample_rate: 1.0)
        assert_profiles_dumped(0) do
          middleware = AppProfiler::Middleware.new(app_env)
          response = call_middleware(middleware, mock_request_env(path: "/"))
          assert_nil(response[1]["x-profile-async"])
        end
      end
    end

    test "request is not sampled when sampler is not enabled via Proc" do
      with_google_cloud_storage do
        AppProfiler.profile_sampler_config = AppProfiler::Sampler::Config.new(sample_rate: 1.0)
        AppProfiler.profile_sampler_enabled = -> { false }
        assert_profiles_dumped(0) do
          middleware = AppProfiler::Middleware.new(app_env)
          response = call_middleware(middleware, mock_request_env(path: "/"))
          assert_nil(response[1]["x-profile-async"])
        end
      end
    end

    test "request clears profile id when finished" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          call_middleware(middleware, mock_request_env(path: "/?profile=cpu"))
        end
      end
      assert_nil(Thread.current[ProfileId::Current::PROFILE_ID_KEY])
    end

    private

    def with_profile_sampler_enabled
      old_status = AppProfiler.profile_sampler_enabled
      AppProfiler.profile_sampler_enabled = true
      yield
    ensure
      AppProfiler.profile_sampler_enabled = old_status
    end

    def with_google_cloud_storage
      old_storage = AppProfiler.storage
      AppProfiler.storage = AppProfiler::Storage::GoogleCloudStorage
      yield
    ensure
      AppProfiler.storage = old_storage
    end

    def with_otel_instrumentation_enabled
      old_status = AppProfiler.otel_instrumentation_enabled
      AppProfiler.otel_instrumentation_enabled = true
      yield
    ensure
      AppProfiler.otel_instrumentation_enabled = old_status
    end

    def app_env
      ->(_) { [200, {}, ["OK"]] }
    end

    def mock_request_env(path: "/", opt: {})
      Rack::MockRequest.env_for("https://app-profiler.com#{path}", opt)
    end

    def with_profile_id_reset
      yield
    ensure
      ProfileId::Current.reset
    end
  end
end
