# frozen_string_literal: true

module AppProfiler
  module Viewer
    class SpeedscopeServerViewer
      class Server
        def initialize
          @speedscope = Rack::File.new(
            File.join(AppProfiler.root, 'node_modules/speedscope/dist/release')
          )
          @profiles_path = AppProfiler.profile_root
        end

        def call(env)
          req = Rack::Request.new(env)
          profiles = @profiles_path.glob("**/*.json")

          if req.path_info == "/"
            # index
            [
              200,
              {"Content-Type" => "text/html"},
              [
                <<~HTML
                <!doctype html>
                <html>
                  <head>
                  </head>
                  <body>
                    #{
                      profiles.map do |profile|
                        "<p><a href=#{profile.basename}>#{profile.basename}</a></p>"
                      end.join("\n")
                    }
                  </body>
                </html>
                HTML
              ]
            ]
          else
            # profile
            id = req.path_info.delete_prefix("/")
            profile = profiles.find do |profile|
              profile.basename.to_s == id
            end
            env[Rack::PATH_INFO] = '/index.html'
            @speedscope.call(env)
          end
        end
      end
    end
  end
end
