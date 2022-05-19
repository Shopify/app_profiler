# frozen_string_literal: true

require "socket"
require "rack"
require "tempfile"

# This module intends to make it easy to pull profiles from a target process via "HTTP"
# It creates a minimal, not-fully-compliant HTTP server, by default on a random port.
#
# Usage:
#
# In target application:
#
#   AppProfiler::Server.start!
#
# Check the port it is listening on by listing the "magic file":
#
#  $ ls -1 /tmp/app_profiler/profileserver-$PID-port-* | sed 's/.*port-\([[:digit:]]*\)-.*/\1/g'
#
# Where "PID" is the pid of the target ruby process, the port will be the next token in the file name
#
# eg:
#
#  $ PID=49825
#  $ port_file=$(ls -1 /tmp/app_profiler/profileserver-$PID-port-*)
#  $ echo $port_file | sed 's/.*port-\([[:digit:]]*\)-.*/\1/g'
#  60160
#
# Alternatively, you can get this port from the application log at the "info" level
#
# Then you start a profiling session like:
#
#  curl '127.0.0.1:60160/profile?duration=10.0&mode=cpu'
#
# The result will be a JSON encoded stackprof profile

module AppProfiler
  module Server
    HTTP_OK = 200
    HTTP_BAD_REQUEST = 400
    HTTP_NOT_FOUND = 404
    HTTP_NOT_ALLOWED = 405
    HTTP_CONFLICT = 409

    mattr_accessor :enabled, default: false
    mattr_accessor :port, default: 0
    mattr_accessor :duration, default: 30

    class ProfileApplication
      class InvalidProfileArgsError < StandardError; end

      def initialize
        @semaphore = Thread::Mutex.new
        @profile_running = false
      end

      def call(env)
        handle(Rack::Request.new(env)).finish
      end

      private

      def handle(request)
        response = Rack::Response.new
        if request.request_method != "GET"
          response.status = HTTP_NOT_ALLOWED
          response.write("Only GET requests are supported")
          return response
        end
        case request.path
        when "/profile"
          begin
            stackprof_args, duration = validate_profile_params(request.params)
          rescue => e
            response.status = HTTP_BAD_REQUEST
            response.write("Invalid argument #{e.message}")
            return response
          end

          if start_running
            AppProfiler.start(**stackprof_args)
            sleep(duration)
            profile = AppProfiler.stop
            stop_running
            response.status = HTTP_OK
            response.set_header("Content-Type", "application/json")
            response.set_header("Access-Control-Allow-Origin", "*")
            response.write(JSON.dump(profile.to_h))
          else
            response.status = HTTP_CONFLICT
            response.write("A profile is already running")
          end
        else
          response.status = HTTP_NOT_FOUND
          response.write("Unsupported endpoint #{request.path}")
        end
        response
      end

      def validate_profile_params(params)
        params = params.symbolize_keys
        stackprof_args = {}
        duration = Float(params.key?(:duration) ? params[:duration] : AppProfiler::Server.duration)
        if params.key?(:mode)
          if ["cpu", "wall", "object"].include?(params[:mode])
            stackprof_args[:mode] = params[:mode].to_sym
          else
            raise InvalidProfileArgsError, "invalid mode #{params[:mode]}"
          end
        end
        if params.key?(:interval)
          stackprof_args[:interval] = params[:interval].to_i
          raise InvalidProfileArgsError, "invalid interval #{params[:interval]}" if stackprof_args[:interval] <= 0
        end
        [stackprof_args, duration]
      end

      # Prevent multiple concurrent profiles by synchronizing between threads
      def start_running
        @semaphore.synchronize do
          return false if @profile_running

          @profile_running = true
        end
      end

      def stop_running
        @semaphore.synchronize { @profile_running = false }
      end
    end

    # This is a minimal, non-compliant "HTTP" server.
    # It will create an extremely minimal rack environment hash and hand it off
    # to our application to process
    class ProfileServer
      PORT_TEMPFILE_PATH = "/tmp/app_profiler" # for tempfile that indicates port in filename
      SERVER_ADDRESS = "127.0.0.1" # it is ONLY safe to run this bound to localhost

      attr_reader :port

      def initialize(port = 0)
        FileUtils.mkdir_p(PORT_TEMPFILE_PATH)
        @server = TCPServer.new(SERVER_ADDRESS, port)
        @listen_thread = nil
        @port = @server.addr[1]
        @port_file = Tempfile.new("profileserver-#{Process.pid}-port-#{@port}-", PORT_TEMPFILE_PATH)
        AppProfiler.logger.info(
          "[AppProfiler::Server] listening on port=#{@port}"
        )
      end

      def serve
        return unless @listen_thread.nil?

        app = ProfileApplication.new

        @listen_thread = Thread.new do
          loop do
            Thread.new(@server.accept) do |session|
              request = session.gets
              if request.nil?
                session.close
                next
              end
              method, path, http_version = request.split(" ")
              path_info, query_string = path.split("?")
              env = { # an extremely minimal rack env hash, just enough to get the job done
                "HTTP_VERSION" => http_version,
                "REQUEST_METHOD" => method,
                "PATH_INFO" => path_info,
                "QUERY_STRING" => query_string,
                "rack.input" => "",
              }
              status, headers, body = app.call(env)

              begin
                session.print("#{http_version} #{status}\r\n")
                headers.each do |header, value|
                  session.print("#{header}: #{value}\r\n")
                end
                session.print("\r\n")
                body.each do |part|
                  session.print(part)
                end
              rescue => e
                AppProfiler.logger.error(
                  "[AppProfiler::Server] exception #{e} responding to request #{request}: #{e.message}"
                )
              ensure
                session.close
              end
            end
          end
        end
      end

      def stop
        @listen_thread.kill
        @port_file.unlink
        @server.close
      end
    end

    class << self
      def start!
        return unless @server.nil?

        @server = ProfileServer.new(AppProfiler::Server.port)
        @server.serve
      end

      def stop!
        return if @server.nil?

        @server.stop
        @server = nil
      end

      def port?
        return if @server.nil?

        @server.port
      end
    end
  end
end
