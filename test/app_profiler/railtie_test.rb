# frozen_string_literal: true

require "test_helper"
require "active_support/testing/isolation"

module AppProfiler
  class RailtieTest < ActiveSupport::TestCase
    # Initializers mutate process-wide configuration.
    include ActiveSupport::Testing::Isolation

    setup do
      Server.reset
      @application = Dummy.new
      @application.config.app_profiler.logger = AppProfiler.logger
      @application.config.app_profiler.root = AppProfiler.root
      @application.config.app_profiler.profile_root = AppProfiler.profile_root
    end

    test "server CORS is enabled when not configured" do
      Server.cors = false
      configure_app_profiler

      assert_equal(true, Server.cors)
      assert_equal("*", profile_response.get_header("Access-Control-Allow-Origin"))
    end

    test "server CORS is enabled when configured as nil" do
      Server.cors = false
      configure_app_profiler(server_cors: nil)

      assert_equal(true, Server.cors)
      assert_equal("*", profile_response.get_header("Access-Control-Allow-Origin"))
    end

    test "server CORS can be explicitly enabled" do
      Server.cors = false
      configure_app_profiler(server_cors: true)

      assert_equal(true, Server.cors)
      assert_equal("*", profile_response.get_header("Access-Control-Allow-Origin"))
    end

    test "server CORS can be explicitly disabled" do
      configure_app_profiler(server_cors: false)

      assert_equal(false, Server.cors)
      refute(profile_response.has_header?("Access-Control-Allow-Origin"))
    end

    test "server CORS honors the configured allowed origin" do
      configure_app_profiler(server_cors: true, server_cors_host: "https://example.com")

      assert_equal(true, Server.cors)
      assert_equal("https://example.com", profile_response.get_header("Access-Control-Allow-Origin"))
    end

    test "server CORS stays disabled with a configured allowed origin" do
      configure_app_profiler(server_cors: false, server_cors_host: "https://example.com")

      assert_equal(false, Server.cors)
      refute(profile_response.has_header?("Access-Control-Allow-Origin"))
    end

    private

    def configure_app_profiler(**options)
      @application.config.app_profiler.merge!(options)
      initializer = Railtie.instance.initializers.find { |entry| entry.name == "app_profiler.configs" }
      initializer.run(@application)
    end

    def profile_response
      response = Rack::MockRequest.new(Server.const_get(:ProfileApplication).new).get(
        "/profile?duration=0.001",
        "HTTP_ORIGIN" => "https://example.com",
      )
      assert(response.ok?)
      response
    end
  end
end
