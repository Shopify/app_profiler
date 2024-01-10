# frozen_string_literal: true

gem "rails-html-sanitizer", ">= 1.6.0"
require "rails-html-sanitizer"

module AppProfiler
  module Viewer
    class FirefoxProfileRemoteViewer < BaseViewer
      class BaseMiddleware
        class Sanitizer < Rails::HTML::Sanitizer.best_supported_vendor.safe_list_sanitizer
          self.allowed_tags = Set.new([
            "strong", "em", "b", "i", "p", "code", "pre", "tt", "samp", "kbd", "var", "sub",
            "sup", "dfn", "cite", "big", "small", "address", "hr", "br", "div", "span", "h1",
            "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "dl", "dt", "dd", "abbr", "acronym",
            "a", "img", "blockquote", "del", "ins", "script",
          ])
        end

        private_constant(:Sanitizer)

        def self.id(file)
          file.basename.to_s#.delete_suffix(".json")
        end

        def initialize(app)
          @app = app
        end

        def call(env)
          request = Rack::Request.new(env)

          return index(env)                        if request.path_info =~ %r(\A/app_profiler/?\z)
          return viewer(env, Regexp.last_match(1)) if request.path_info =~ %r(\A/app_profiler/viewer/(.*)\z)
          return show(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/app_profiler/(.*)\z)

          # Firefox profiler *really* doesn't like for /from-url/ to be at any other mount point
          # so with this enabled, we take over both /app_profiler and /from-url in the app in development.
          return from(env, Regexp.last_match(1))   if request.path_info =~ %r(\A/from-url(.*)\z)

          @app.call(env)
        end

        protected

        def id(file)
          self.class.id(file)
        end

        def profile_files
          AppProfiler.profile_root.glob("**/*.json")
        end

        def render(html)
          [
            200,
            { "Content-Type" => "text/html" },
            [
              +<<~HTML,
                <!doctype html>
                <html>
                  <head>
                    <title>App Profiler</title>
                  </head>
                  <body>
                    #{sanitizer.sanitize(html)}
                  </body>
                </html>
              HTML
            ],
          ]
        end

        def sanitizer
          @sanitizer ||= Sanitizer.new
        end

        def viewer(_env, path)
          raise NotImplementedError
        end

        def index(_env)
          render(
            (+"").tap do |content|
              content << "<h1>Profiles</h1>"
              profile_files.each do |file|
                content << <<~HTML
                  <p>
                    <a href="/app_profiler/viewer/#{id(file)}">
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

      private_constant(:BaseMiddleware)
    end
  end
end
