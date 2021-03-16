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

        protected

        attr_reader(:speedscope)

        def viewer(env, path)
          setup_yarn unless yarn_setup
          env[Rack::PATH_INFO] = path.delete_prefix("/app_profiler")

          speedscope.call(env)
        end

        def show(_env, name)
          profile = profile_files.find do |file|
            id(file) == name
          end || raise(ArgumentError)

          render(
            <<~HTML
              <script type="text/javascript">
                var graph = #{profile.read};
                var json = JSON.stringify(graph);
                var blob = new Blob([json], { type: 'text/plain' });
                var objUrl = encodeURIComponent(URL.createObjectURL(blob));
                var iframe = document.createElement('iframe');

                document.body.style.margin = '0px';
                document.body.appendChild(iframe);

                iframe.style.width = '100vw';
                iframe.style.height = '100vh';
                iframe.style.border = 'none';
                iframe.setAttribute('src', '/app_profiler/viewer/index.html#profileURL=' + objUrl + '&title=' + 'Flamegraph for #{name}');
              </script>
            HTML
          )
        end
      end
    end
  end
end
