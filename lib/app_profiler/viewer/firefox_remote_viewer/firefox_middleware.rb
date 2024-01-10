# frozen_string_literal: true

require "app_profiler/yarn/command"
require "app_profiler/yarn/with_firefox_profiler"

module AppProfiler
  module Viewer
    class FirefoxProfileRemoteViewer < BaseViewer
      class Middleware < BaseMiddleware
        include Yarn::WithFirefoxProfile

        def initialize(app)
          super
          @firefox_profiler = Rack::File.new(
            File.join(AppProfiler.root, "node_modules/firefox-profiler/dist")
          )

# http://192.168.64.1:36109/app_profiler/viewer/from-url/
# http%3A%2F%2F192.168.64.1%3A36109%2Fapp_profiler%2F20240109-185136-wall-105380f9e30e1d5f8a9218ea963c87d9-Dales-Laptop.localdomain
# http://192.168.64.1:36109/from-url/http%3A%2F%2F192.168.64.1%3A36109%2Fapp_profiler%2F20240109-185136-wall-105380f9e30e1d5f8a9218ea963c87d9-Dales-Laptop.localdomain

# http://192.168.64.1:36109/from-url/http%3A%2F%2F192.168.64.1%3A36109%2Fapp_profiler%2F20240109-185136-wall-105380f9e30e1d5f8a9218ea963c87d9-Dales-Laptop.localdomain.json


        end

        protected

        attr_reader(:firefox_profiler)

        def viewer(env, path)
          setup_yarn unless yarn_setup

          if path.ends_with?(".json")
            proto = "http"
            host = env['HTTP_HOST']
            puts path
            source = "#{proto}://#{host}/app_profiler/#{path.gsub("/viewer", "")}"
            puts "SOURCE #{source}"

            target = "/from-url/#{CGI.escape(source)}"
      
            ['302', {'Location' => target}, []]
          else
            env[Rack::PATH_INFO] = path.delete_prefix("/app_profiler")
            firefox_profiler.call(env)
          end
        end

        def from(env, path)
          setup_yarn unless yarn_setup
          index = File.read(File.join(AppProfiler.root, "node_modules/firefox-profiler/dist/index.html"))
          ['200', {"Content-Type" => "text/html"}, [index]]
        end

        def show(_env, name)
          profile = profile_files.find do |file|
            id(file) == name
          end || raise(ArgumentError)

          ['200', {'Content-Type' => 'application/json'}, [profile.read]]
        end
      end
    end
  end
end
