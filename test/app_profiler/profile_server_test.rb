# frozen_string_literal: true

require "test_helper"
require "net/http"

module AppProfiler
  module Server
    TEST_PORT = 11337
    class ServerTest < TestCase
      def setup
        AppProfiler::Server.port = 0
      end

      test ".start! creates a profile server listening on defined port" do
        AppProfiler.logger.expects(:info).with { |value| value =~ /listening on port=#{TEST_PORT}/ }
        Server.port = TEST_PORT
        assert_not_nil(Server.start!)
        assert_not_nil(TCPSocket.new(ProfileServer::SERVER_ADDRESS, TEST_PORT))
      ensure
        assert_nil(Server.stop!)
      end

      test ".start! creates a profile server on random free port with undefined port" do
        AppProfiler.logger.expects(:info).with { |value| value =~ /listening on port/ }
        assert_not_nil(Server.start!)
        assert_not_nil(TCPSocket.new(ProfileServer::SERVER_ADDRESS, Server.port?))
      ensure
        assert_nil(Server.stop!)
      end

      test ".stop! stops running profile server" do
        AppProfiler.logger.expects(:info).with { |value| value =~ /listening on port=#{TEST_PORT}/ }
        Server.port = TEST_PORT
        assert_not_nil(Server.start!)
        assert_not_nil(TCPSocket.new(ProfileServer::SERVER_ADDRESS, TEST_PORT))
        assert_nil(Server.stop!)
        assert_raises(Errno::ECONNREFUSED) { TCPSocket.new(ProfileServer::SERVER_ADDRESS, TEST_PORT) }
      ensure
        assert_nil(Server.stop!)
      end

      test ".port? returns the server port" do
        AppProfiler.logger.expects(:info).with { |value| value =~ /listening on port=#{TEST_PORT}/ }
        Server.port = TEST_PORT
        assert_not_nil(Server.start!)
        assert_equal(TEST_PORT, Server.port?)
      ensure
        assert_nil(Server.stop!)
      end
    end

    class ProfileServerTest < TestCase
      test ".serve starts a TCP server listening on a socket" do
        with_test_server(false) do |server|
          server.serve
          assert_not_nil(TCPSocket.new(ProfileServer::SERVER_ADDRESS, server.port))
        end
      end

      test ".serve starts a socket that responds with valid HTTP response" do
        with_test_server(false) do |server|
          server.serve
          socket = TCPSocket.new(ProfileServer::SERVER_ADDRESS, server.port)
          socket.write("GET / HTTP/1.0\r\n\r\n")
          response = socket.read
          expected_response = <<~RESPONSE
            HTTP/1.0 404\r
            Content-Length: 22\r
            \r
            Unsupported endpoint /
          RESPONSE
          assert_equal(expected_response.strip, response)
        end
      end

      test ".serve starts a socket that serves valid JSON profiles over HTTP" do
        with_test_server(false) do |server|
          server.serve
          socket = TCPSocket.new(ProfileServer::SERVER_ADDRESS, server.port)
          socket.write("GET /profile?duration=0.001 HTTP/1.0\r\n\r\n")
          response = socket.read
          lines = response.lines
          assert(lines.shift.match?(/HTTP.*200/))
          assert_equal("Content-Type: application/json\r\n", lines.shift)
          assert_equal("Access-Control-Allow-Origin: *\r\n", lines.shift)
          length_line = lines.shift
          assert(length_line =~ (/Content-Length: (.*)/))
          content_length = Regexp.last_match(1).to_i
          assert_equal("\r\n", lines.shift)
          body = lines.shift
          assert_equal(content_length, body.size)
          assert(JSON.parse(body))
        end
      end

      test ".serve starts a server that responds to an HTTP request" do
        with_test_server(false) do |server|
          server.serve
          assert_not_nil(TCPSocket.new(ProfileServer::SERVER_ADDRESS, server.port))
          uri = URI("http://#{ProfileServer::SERVER_ADDRESS}:#{server.port}/")
          assert_equal("404", Net::HTTP.get_response(uri).code)
        end
      end

      test ".serve creates magic tempfile with pid : port mapping encoded in name" do
        with_test_server(false) do |server|
          server.serve
          port_files = Dir["#{ProfileServer::PORT_TEMPFILE_PATH}/profileserver-#{Process.pid}-*"]
          assert_equal(1, port_files.size)
          port_file = port_files.first
          matches = port_file.match(/port-(\d+)-/)
          assert_equal(2, matches.size)
          assert_equal(server.port, matches[1].to_i)
        end
      end

      test ".stop stops profile server" do
        with_test_server do |server|
          assert_nil(server.stop)
          assert_raises(Errno::ECONNREFUSED) { TCPSocket.new(ProfileServer::SERVER_ADDRESS, server.port) }
        end
      end

      test ".port returns the server port" do
        with_test_server(true, TEST_PORT) do |server|
          assert_equal(TEST_PORT, server.port)
        end
      end

      private

      def with_test_server(start = true, port = 0, &block)
        AppProfiler.logger.expects(:info).with { |value| value =~ /listening on port/ }
        server = ProfileServer.new(port)
        if start
          server.serve
        end
        yield server
      ensure
        assert_nil(server.stop)
      end
    end

    class ProfileApplicationTest < TestCase
      include Rack::Test::Methods

      def setup
        Server.port = 0
        Server.cors = true
        Server.cors_host = "*"
      end

      def app
        ProfileApplication.new
      end

      test "app responds with 405 to unsupported method" do
        post("/profile?duration=1")
        assert_equal(decode_status(last_response.status), Net::HTTPMethodNotAllowed)
      end

      test "app responds with 404 to unknown path" do
        get("/bad_endpoint")
        assert_equal(decode_status(last_response.status), Net::HTTPNotFound)
      end

      test "app responds with 400 with invalid duration" do
        get("/profile?duration=foo")
        assert_equal(decode_status(last_response.status), Net::HTTPBadRequest)
      end

      test "app responds with 400 with invalid mode" do
        get("/profile?mode=unsupported_mode")
        assert_equal(decode_status(last_response.status), Net::HTTPBadRequest)
      end

      test "app responds with 400 with invalid interval" do
        get("/profile?interval=0")
        assert_equal(decode_status(last_response.status), Net::HTTPBadRequest)
      end

      test "app returns valid JSON" do
        get("/profile?duration=0.01")
        assert(last_response.ok?)
        JSON.parse(last_response.body)
        assert_equal(last_response.get_header("Content-Type"), "application/json")
      end

      test "app returns JSON with extra start time" do
        get("/profile?duration=0.01")
        assert(last_response.ok?)
        profile = JSON.parse(last_response.body)
        assert(profile.key?("start_time_nsecs"))
      end

      test "app allows CORS by default" do
        get("/profile?duration=0.01")
        assert(last_response.ok?)
        assert(last_response.has_header?("Access-Control-Allow-Origin"))
        assert_equal(last_response.get_header("Access-Control-Allow-Origin"), "*")
      end

      test "app can disable CORS" do
        Server.cors = false
        get("/profile?duration=0.01")
        assert(last_response.ok?)
        refute(last_response.has_header?("Access-Control-Allow-Origin"))
      end

      test "app can limit the CORS allowed host host" do
        Server.cors_host = "foo"
        get("/profile?duration=0.01")
        assert(last_response.ok?)
        assert(last_response.has_header?("Access-Control-Allow-Origin"))
        assert_equal(last_response.get_header("Access-Control-Allow-Origin"), "foo")
      end

      test "app runs a profile for the correct interval" do
        get("/profile?duration=0.01&interval=1000")
        assert(last_response.ok?)
        profile = JSON.parse(last_response.body)
        assert_equal(1000, profile["interval"])
      end

      test "app responds with valid profile to /profile defaulting to cpu mode" do
        with_profiled_workload(proc { loop {} }) do
          get("/profile?duration=0.1")
        end
        assert(last_response.ok?)
        profile = JSON.parse(last_response.body)
        assert_equal(profile["mode"], "cpu")
        assert_operator profile["samples"], :>, 0
      end

      test "app responds with valid profile wall profile to /profile" do
        with_profiled_workload(proc { loop { sleep(0.001) } }) do
          get("/profile?duration=0.1&mode=wall")
        end
        assert(last_response.ok?)
        profile = JSON.parse(last_response.body)
        assert_equal(profile["mode"], "wall")
        assert_operator(profile["samples"], :>, 0)
      end

      test "app responds with valid object profile to /profile" do
        workload = proc do
          loop do
            _ = {}
            sleep(0.01)
          end
        end

        with_profiled_workload(workload) do
          get("/profile?duration=0.1&mode=object")
        end

        assert(last_response.ok?)
        profile = JSON.parse(last_response.body)
        assert_equal(profile["mode"], "object")
        assert_operator(profile["samples"], :>, 0)
      end

      test "app responds with conflict if profile already running" do
        req = Thread.new do
          get("/profile?duration=0.2")
          assert(last_response.ok?)
        end

        sleep(0.01)
        get("/profile?duration=0.1")
        assert_equal(decode_status(last_response.status), Net::HTTPConflict)
        req.join
      end

      private

      def with_profiled_workload(workload, &block)
        work = Thread.new do
          workload.call
        end
        yield
      ensure
        work.kill
      end

      def decode_status(status)
        Net::HTTPResponse::CODE_TO_OBJ[status.to_s]
      end
    end
  end
end
