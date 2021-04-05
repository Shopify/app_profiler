# frozen_string_literal: true

module AppProfiler
  module Viewer
    class BaseMiddleware
      def initialize(app)
        @app = app
        @profiles_path = AppProfiler.profile_root
      end

      def call(env)
        request = Rack::Request.new(env)

        return index(env)                        if request.path_info =~ %r(\A/app_profiler\z)
        return viewer(env, Regexp.last_match(1)) if request.path_info =~ %r(\A/app_profiler/viewer/(.*)\z)
        return show(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/app_profiler/(.*)\z)

        @app.call(env)
      end

      protected

      def profile_files
        @profile_files ||= @profiles_path.glob("**/*.json")
      end

      def render(html)
        [
          200,
          {"Content-Type" => "text/html"},
          [
            +<<~HTML
              <!doctype html>
              <html>
                <head>
                  <title>App Profiler</title>
                </head>
                <body>
                  #{html}
                </body>
              </html>
            HTML
          ]
        ]
      end

      def id(file)
        file.basename.to_s.delete_suffix(".json")
      end

      def viewer(_env, path)
        raise NotImplementedError
      end

      def index(_env)
        render(
          String.new.tap do |content|
            content << "<h1>Profiles</h1>"
            profile_files.each do |file|
              content << <<~HTML
                <p>
                  <a href=/app_profiler/#{id(file)}>
                    #{id(file)}
                  </a>
                </p>
              HTML
            end
          end
        )
      end

      def show(env, id)
        raise NotImplementedError
      end
    end
  end
end
