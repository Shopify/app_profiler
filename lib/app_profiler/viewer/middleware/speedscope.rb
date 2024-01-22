# frozen_string_literal: true

require "app_profiler/yarn/command"
require "app_profiler/yarn/with_speedscope"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewer < BaseViewer
      class Middleware < BaseMiddleware
        include Yarn::WithSpeedscope

        def initialize(app)
          super
          @speedscope = Rack::File.new(
            File.join(AppProfiler.root, "node_modules/speedscope/dist/release")
          )
        end

        def call(env)
          request = Rack::Request.new(env)
          @app.call(env) if request.path_info.end_with?(AppProfiler::VernierProfile::FILE_EXTENSION)
          return viewer(env, Regexp.last_match(1)) if request.path_info =~ %r(\A/app_profiler/speedscope/viewer/(.*)\z)
          return show(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/app_profiler/speedscope/(.*)\z)

          super
        end

        protected

        attr_reader(:speedscope)

        def viewer(env, path)
          setup_yarn unless yarn_setup

          if path.end_with?(AppProfiler::StackprofProfile::FILE_EXTENSION)
            source = "/app_profiler/speedscope/#{path}"
            target = "/app_profiler/speedscope/viewer/index.html#profileURL=#{CGI.escape(source)}"

            [302, { "Location" => target }, []]
          else
            env[Rack::PATH_INFO] = path.delete_prefix("/app_profiler/speedscope")
            speedscope.call(env)
          end
        end

        def show(_env, name)
          profile = profile_files.find do |file|
            id(file) == name
          end || raise(ArgumentError)

          [200, { "Content-Type" => "application/json" }, [profile.read]]
        end
      end
    end
  end
end
