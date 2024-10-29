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
            File.join(AppProfiler.root, "node_modules/speedscope/dist/release"),
          )
        end

        def call(env)
          request = Rack::Request.new(env)

          return viewer(env, Regexp.last_match(1)) if request.path_info =~ %r(\A/app_profiler/speedscope/viewer/(.*)\z)
          return show(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/app_profiler/speedscope/(.*)\z)

          super
        end

        protected

        attr_reader(:speedscope)

        def viewer(env, path)
          setup_yarn unless yarn_setup

          env[Rack::PATH_INFO] = path.delete_prefix("/app_profiler/speedscope")
          speedscope.call(env)
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
