# frozen_string_literal: true

require "test_helper"

module AppProfiler
  class MiddlewareTest < TestCase
    test "requests are not profiled by default" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        middleware.call(mock_request_env)
      end
    end

    test "profiles are uploaded when request is profiled" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          middleware.call(mock_request_env(path: "/?profile=cpu"))
        end
      end
    end

    AppProfiler::StackprofBackend::AVAILABLE_MODES.each do |mode|
      test "profile mode #{mode} is supported by stackprof backend" do
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            middleware.call(mock_request_env(path: "/?profile=#{mode}"))
          end
        end
      end
    end

    if defined?(AppProfiler::VernierBackend)
      AppProfiler::VernierBackend::AVAILABLE_MODES.each do |mode|
        test "profile mode #{mode} is supported by vernier backend" do
          assert_profiles_dumped do
            assert_profiles_uploaded do
              middleware = AppProfiler::Middleware.new(app_env)
              middleware.call(mock_request_env(path: "/?profile=#{mode}&backend=vernier"))
            end
          end
        end
      end
    end

    if defined?(AppProfiler::VernierBackend)
      test "the backend can be toggled between requests" do
        assert_profiles_dumped(3) do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            middleware.call(mock_request_env(path: "/?profile=wall&backend=stackprof"))
          end

          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            middleware.call(mock_request_env(path: "/?profile=wall&backend=vernier"))
          end

          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            middleware.call(mock_request_env(path: "/?profile=wall&backend=stackprof"))
          end

          assert_equal(2, tmp_profiles.count { |p| p.to_s =~ /#{AppProfiler::StackprofProfile::FILE_EXTENSION}$/ })
          assert_equal(1, tmp_profiles.count { |p| p.to_s =~ /#{AppProfiler::VernierProfile::FILE_EXTENSION}$/ })
        end
      end
    end

    test "profile interval is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          middleware.call(mock_request_env(path: "/?profile=cpu&interval=2000"))
        end
      end
    end

    test "interval without profile mode will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        middleware.call(mock_request_env(path: "/?interval=2000"))
      end
    end

    test "autoredirect with profile is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          middleware.call(mock_request_env(path: "/?profile=cpu&autoredirect=1"))
        end
      end
    end

    test "autoredirect config with profile is supported" do
      AppProfiler.autoredirect = true
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          middleware.call(mock_request_env(path: "/?profile=cpu"))
        end
      end
      AppProfiler.autoredirect = false
    end

    test "autoredirect without profile will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        middleware.call(mock_request_env(path: "/?autoredirect=1"))
      end
    end

    test "ignore_gc option is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          middleware.call(mock_request_env(path: "/?profile=cpu&ignore_gc=1"))
        end
      end
    end

    test "ignore_gc option through headers is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu;interval=2000;ignore_gc=1" }
          middleware.call(mock_request_env(opt: opt))
        end
      end
    end

    test "invalid profile mode will not profile" do
      assert_profiles_dumped(0) do
        AppProfiler.logger.expects(:info).with { |value| value =~ /unsupported profiling mode=hello/ }
        middleware = AppProfiler::Middleware.new(app_env)
        middleware.call(mock_request_env(path: "/?profile=hello"))
      end
    end

    test "invalid profile interval will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        middleware.call(mock_request_env(path: "/?profile=cpu&interval=1"))
      end
    end

    test "profiles will not be generated when query string failed to be parsed" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        middleware.call(
          mock_request_env(
            path: <<~PATH.delete("\n")
              /?profile=cpu&contact%5Bemail%5D]%F0%9D%92%B6]%F0%9D%92%B6]%22]
              %22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]]%22]
              %22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]]%22]%22]
              %22]%22]%22]%22%22]%22]%22]%22]%22]]%22]%22]%22]%22]%22]%22]%22]]%22]%22]%22]%22]%22]%22]%22]%22]%22]
              %22]]%22]%22%22]%22]%22]%22]%22]%22]%22]%22]%22]%22]]%22]%22]%22]%22]%22]%22]%22%22]%22]%22]%22]
            PATH
          )
        )
      end
    end

    test "profile upload error prints logs" do
      AppProfiler.stubs(:storage).returns(MockStorage)
      AppProfiler.logger.expects(:info).with { |value| value =~ /failed to upload profile/ }
      middleware = AppProfiler::Middleware.new(app_env)
      AppProfiler.storage.stubs(:upload).raises(StandardError, "upload error")
      response = middleware.call(mock_request_env(path: "/?profile=cpu"))
      assert_nil(response[1][AppProfiler.profile_header])
      assert_nil(response[1][AppProfiler.profile_data_header])
    end

    test "profiles are uploaded when request is profiled through headers" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu" }
          middleware.call(mock_request_env(opt: opt))
        end
      end
    end

    AppProfiler::StackprofBackend::AVAILABLE_MODES.each do |mode|
      test "profile mode #{mode} through headers is supported" do
        assert_profiles_dumped do
          assert_profiles_uploaded do
            middleware = AppProfiler::Middleware.new(app_env)
            opt = { AppProfiler.request_profile_header => "mode=#{mode}" }
            middleware.call(mock_request_env(opt: opt))
          end
        end
      end
    end

    if defined?(AppProfiler::VernierBackend)
      AppProfiler::VernierBackend::AVAILABLE_MODES.each do |mode|
        test "profile mode #{mode} is supported through headers by vernier backend" do
          assert_profiles_dumped do
            assert_profiles_uploaded do
              middleware = AppProfiler::Middleware.new(app_env)
              opt = { AppProfiler.request_profile_header => "mode=#{mode};backend=vernier" }
              middleware.call(mock_request_env(opt: opt))
            end
          end
        end
      end
    end

    test "profile interval through headers is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu;interval=2000" }
          middleware.call(mock_request_env(opt: opt))
        end
      end
    end

    test "autoredirect with profile through headers is supported" do
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu;autoredirect=1" }
          middleware.call(mock_request_env(opt: opt))
        end
      end
    end

    test "autoredirect config with profile through headers is supported" do
      AppProfiler.autoredirect = true
      assert_profiles_dumped do
        assert_profiles_uploaded(autoredirect: true) do
          middleware = AppProfiler::Middleware.new(app_env)
          opt = { AppProfiler.request_profile_header => "mode=cpu" }
          middleware.call(mock_request_env(opt: opt))
        end
      end
      AppProfiler.autoredirect = false
    end

    test "invalid profile mode in headers will not profile" do
      assert_profiles_dumped(0) do
        AppProfiler.logger.expects(:info).with { |value| value =~ /unsupported profiling mode=hello/ }
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "mode=hello" }
        middleware.call(mock_request_env(opt: opt))
      end
    end

    test "invalid profile interval in headers will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "mode=cpu;interval=1" }
        middleware.call(mock_request_env(opt: opt))
      end
    end

    test "headers using & will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "mode=cpu&interval=1" }
        middleware.call(mock_request_env(opt: opt))
      end
    end

    test "invalid profile headers will not profile" do
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        opt = { AppProfiler.request_profile_header => "helloworld" }
        middleware.call(mock_request_env(opt: opt))
      end
    end

    test "invalid profile will not be uploaded" do
      AppProfiler.expects(:run).returns(nil)
      AppProfiler.middleware.action.expects(:call).never
      middleware = AppProfiler::Middleware.new(app_env)
      opt = { AppProfiler.request_profile_header => "mode=cpu;interval=2000" }
      middleware.call(mock_request_env(opt: opt))
    end

    test "should not profile if #before_profile returns false" do
      AppProfiler.expects(:run).never
      AppProfiler.middleware.any_instance.stubs(:before_profile).returns(false)

      middleware = AppProfiler::Middleware.new(app_env)
      middleware.call(mock_request_env(path: "/?profile=cpu"))
    end

    test "should not upload if #after_profile returns false" do
      AppProfiler.expects(:run).returns({})
      AppProfiler.middleware.action.expects(:call).never
      AppProfiler.middleware.any_instance.stubs(:after_profile).returns(false)

      middleware = AppProfiler::Middleware.new(app_env)
      middleware.call(mock_request_env(path: "/?profile=cpu"))
    end

    test "#before_profile called with env and profiling params" do
      request_env = mock_request_env(path: "/?profile=cpu")
      AppProfiler.middleware.any_instance.expects(:before_profile).with do |env, params|
        request_env == env && params.is_a?(Hash)
      end.returns(false)
      middleware = AppProfiler::Middleware.new(app_env)
      middleware.call(request_env)
    end

    test "#after_profile called with env and profile data" do
      request_env = mock_request_env(path: "/?profile=cpu")
      AppProfiler.middleware.any_instance.expects(:after_profile).with do |env, profile|
        request_env == env && profile.is_a?(AppProfiler::Profile)
      end.returns(false)
      middleware = AppProfiler::Middleware.new(app_env)
      middleware.call(request_env)
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
            return false unless request_env == env && profile.is_a?(AppProfiler::Profile)

            profile[:metadata][:test_key] == "test_value"
          end.returns(true)

          middleware = AppProfiler::Middleware.new(app_env)
          middleware.call(request_env)
        end
      end
    end

    test "profiles are not uploaded synchronously when async is requested" do
      old_storage = AppProfiler.storage
      AppProfiler.storage = AppProfiler::Storage::GoogleCloudStorage
      assert_profiles_dumped(0) do
        middleware = AppProfiler::Middleware.new(app_env)
        response = middleware.call(mock_request_env(path: "/?profile=cpu&async=true"))
        assert(response[1]["X-Profile-Async"])
      end
    ensure
      AppProfiler::Storage::GoogleCloudStorage.reset_queue # kill the background thread and reset the queue
      AppProfiler.storage = old_storage
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
          middleware.call(mock_request_env)
        end
      end
    end

    private

    def app_env
      ->(_) { [200, {}, ["OK"]] }
    end

    def mock_request_env(path: "/", opt: {})
      Rack::MockRequest.env_for("https://app-profiler.com#{path}", opt)
    end
  end
end
