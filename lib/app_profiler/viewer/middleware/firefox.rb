# frozen_string_literal: true

require "app_profiler/yarn/command"
require "app_profiler/yarn/with_firefox_profiler"

module AppProfiler
  module Viewer
    class FirefoxRemoteViewer < BaseViewer
      class Middleware < BaseMiddleware
        include Yarn::WithFirefoxProfile

        def initialize(app)
          super
          @firefox_profiler = Rack::File.new(
            File.join(AppProfiler.root, "node_modules/firefox-profiler/dist")
          )
        end

        def call(env)
          request = Rack::Request.new(env)
          @app.call(env) if request.path_info.end_with?(AppProfiler::StackprofProfile::FILE_EXTENSION)
          # Firefox profiler *really* doesn't like for /from-url/ to be at any other mount point
          # so with this enabled, we take over both /app_profiler and /from-url in the app in development.
          return from(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/from-url(.*)\z)
          return viewer(env, Regexp.last_match(1)) if request.path_info =~ %r(\A/app_profiler/firefox/viewer/(.*)\z)
          return show(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/app_profiler/firefox/(.*)\z)

          super
        end

        protected

        attr_reader(:firefox_profiler)

        def viewer(env, path)
          setup_yarn unless yarn_setup

          if path.end_with?(AppProfiler::VernierProfile::FILE_EXTENSION)
            proto = env["rack.url_scheme"]
            host = env["HTTP_HOST"]
            source = "#{proto}://#{host}/app_profiler/firefox/#{path}"

            target = "/from-url/#{CGI.escape(source)}"

            [302, { "Location" => target }, []]
          else
            env[Rack::PATH_INFO] = path.delete_prefix("/app_profiler")
            firefox_profiler.call(env)
          end
        end

        def from(env, path)
          setup_yarn unless yarn_setup
          index = File.read(File.join(AppProfiler.root, "node_modules/firefox-profiler/dist/index.html"))
          [200, { "Content-Type" => "text/html" }, [index]]
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
