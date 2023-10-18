# frozen_string_literal: true

require "socket"
require "rack"
require "tempfile"
require "json"
require "active_support/core_ext/hash"
require "active_support/core_ext/module"

# This module provides a means to start a golang-inspired profile server
# it is implemented using stdlib and Rack to avoid additional dependencies

module AppProfiler
  module Server
    HTTP_OK = 200
    HTTP_BAD_REQUEST = 400
    HTTP_NOT_FOUND = 404
    HTTP_NOT_ALLOWED = 405
    HTTP_CONFLICT = 409

    TRANSPORT_UNIX = "unix"
    TRANSPORT_TCP = "tcp"

    DEFAULTS = {
      enabled: false,
      transport: TRANSPORT_UNIX,
      cors: true,
      cors_host: "*",
      port: 0,
      duration: 30,
    }

    mattr_accessor :enabled, default: DEFAULTS[:enabled]
    mattr_accessor :transport, default: DEFAULTS[:transport]
    mattr_accessor :cors, default: DEFAULTS[:cors]
    mattr_accessor :cors_host, default: DEFAULTS[:cors_host]
    mattr_accessor :port, default: DEFAULTS[:port]
    mattr_accessor :duration, default: DEFAULTS[:duration]

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
        return handle_not_allowed(request) if request.request_method != "GET"

        case request.path
        when "/profile"
          handle_profile(request)
        else
          handle_not_found(request)
        end
      end

      def handle_not_allowed(request)
        response = Rack::Response.new

        response.status = HTTP_NOT_ALLOWED
        response.write("Only GET requests are supported")

        response
      end

      def handle_profile(request)
        begin
          stackprof_args, duration = validate_profile_params(request.params)
        rescue InvalidProfileArgsError => e
          return handle_bad_request(request, e.message)
        end

        response = Rack::Response.new

        if start_running(stackprof_args)
          start_time = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)

          sleep(duration)

          profile = stop_running

          response.status = HTTP_OK
          response.set_header("Content-Type", "application/json")

          profile_hash = profile.to_h
          profile_hash["start_time_nsecs"] = start_time # NOTE: this is not part of the stackprof profile spec

          response.write(JSON.dump(profile_hash))

          if AppProfiler::Server.cors
            response.set_header("Access-Control-Allow-Origin", AppProfiler::Server.cors_host)
          end
        else
          response.status = HTTP_CONFLICT
          response.write("A profile is already running")
        end

        response
      end

      def handle_not_found(request)
        response = Rack::Response.new

        response.status = HTTP_NOT_FOUND
        response.write("Unsupported endpoint #{request.path}")

        response
      end

      def handle_bad_request(request, message)
        response = Rack::Response.new

        response.status = HTTP_BAD_REQUEST
        response.write("Invalid argument #{message}")

        response
      end

      def validate_profile_params(params)
        params = params.symbolize_keys
        stackprof_args = {}

        begin
          duration = Float(params.key?(:duration) ? params[:duration] : AppProfiler::Server.duration)
        rescue ArgumentError
          raise InvalidProfileArgsError, "duration: #{params[:duration]}"
        end

        if params.key?(:mode)
          if ["cpu", "wall", "object"].include?(params[:mode])
            stackprof_args[:mode] = params[:mode].to_sym
          else
            raise InvalidProfileArgsError, "mode: #{params[:mode]}"
          end
        end

        if params.key?(:interval)
          stackprof_args[:interval] = params[:interval].to_i

          raise InvalidProfileArgsError, "interval: #{params[:interval]}" if stackprof_args[:interval] <= 0
        end

        [stackprof_args, duration]
      end

      # Prevent multiple concurrent profiles by synchronizing between threads
      def start_running(stackprof_args)
        @semaphore.synchronize do
          return false if @profile_running

          @profile_running = true

          AppProfiler.start(**stackprof_args)
        end
      end

      def stop_running
        @semaphore.synchronize do
          AppProfiler.stop.tap do
            @profile_running = false
          end
        end
      end
    end

    # This is a minimal, non-compliant "HTTP" server.
    # It will create an extremely minimal rack environment hash and hand it off
    # to our application to process
    class ProfileServer
      PROFILER_TEMPFILE_PATH = "/tmp/app_profiler" # for tempfile that indicates port in filename or unix sockets

      class Transport
        attr_reader :socket

        def initialize
          start
        end

        def start
          raise(NotImplementedError)
        end

        def client
          raise(NotImplementedError)
        end

        def stop
          raise(NotImplementedError)
        end
      end

      class UNIX < Transport
        class << self
          def unlink_socket(path, pid)
            ->(_) do
              if Process.pid == pid && File.exist?(path)
                begin
                  File.unlink(path)
                rescue SystemCallError
                  # Let not raise in a finalizer
                end
              end
            end
          end
        end

        def start
          FileUtils.mkdir_p(PROFILER_TEMPFILE_PATH)
          @socket_file = File.join(PROFILER_TEMPFILE_PATH, "app-profiler-#{Process.pid}.sock")
          File.unlink(@socket_file) if File.exist?(@socket_file) && File.socket?(@socket_file)
          @socket = UNIXServer.new(@socket_file)
          ObjectSpace.define_finalizer(self, self.class.unlink_socket(@socket_file, Process.pid))
        end

        def client
          UNIXSocket.new(@socket_file)
        end

        def stop
          @socket.close
          File.unlink(@socket_file) if File.exist?(@socket_file) && File.socket?(@socket_file)
          ObjectSpace.undefine_finalizer(self)
          nil
        end

        def abandon
          @socket.close
        end
      end

      class TCP < Transport
        SERVER_ADDRESS = "127.0.0.1" # it is ONLY safe to run this bound to localhost

        def initialize(port = 0)
          @port_argument = port
          super()
        end

        def start
          FileUtils.mkdir_p(PROFILER_TEMPFILE_PATH)
          @socket = TCPServer.new(SERVER_ADDRESS, @port_argument)
          @port = @socket.addr[1]
          @port_file = Tempfile.new("profileserver-#{Process.pid}-port-#{@port}-", PROFILER_TEMPFILE_PATH)
        end

        def client
          TCPSocket.new(SERVER_ADDRESS, @port)
        end

        def stop
          @port_file.unlink
          @socket.close
        end

        def abandon
          @port_file.close # NB: Tempfile finalizer checks Process.pid to avoid unlinking inherited IOs.
          @socket.close
        end
      end

      def initialize(transport, logger)
        @logger = logger
        case transport
        when TRANSPORT_UNIX
          @transport = ProfileServer::UNIX.new
        when TRANSPORT_TCP
          @transport = ProfileServer::TCP.new(AppProfiler::Server.port)
        else
          raise "invalid transport #{transport}"
        end

        @listen_thread = nil

        @logger.info(
          "[AppProfiler::Server] listening on addr=#{@transport.socket.addr}"
        )
        @pid = Process.pid
      end

      def client
        @transport.client
      end

      def join(...)
        @listen_thread.join(...)
      end

      def serve
        return unless @listen_thread.nil?

        app = ProfileApplication.new

        @listen_thread = Thread.new do
          loop do
            session = begin
              @transport.socket.accept
            rescue
              @transport.close
              @transport.start
              next
            end

            Thread.new(session) do |session|
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
                @logger.error(
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
        if @pid == Process.pid
          @transport.stop
        else
          @transport.abandon
        end
      end
    end

    private_constant :ProfileApplication, :ProfileServer

    @pid = Process.pid
    @profile_server = nil

    class << self
      def reset
        self.profile_server = nil

        DEFAULTS.each do |config, value|
          class_variable_set(:"@@#{config}", value) # rubocop:disable Style/ClassVars
        end
      end

      def start(logger = Logger.new(IO::NULL))
        return if profile_server

        self.profile_server = ProfileServer.new(AppProfiler::Server.transport, logger)
        profile_server.serve
        profile_server
      end

      def client
        return unless profile_server

        profile_server.client
      end

      def stop
        return unless profile_server

        server = profile_server
        server.stop
        self.profile_server = nil
        server
      end

      private

      def profile_server
        if @pid != Process.pid
          @profile_server&.stop
          @profile_server = nil
        end
        @profile_server
      end

      def profile_server=(server)
        @pid = Process.pid
        @profile_server = server
      end
    end
  end
end
