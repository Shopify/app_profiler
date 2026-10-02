# frozen_string_literal: true

require "test_helper"
require "cgi"

module AppProfiler
  module Viewer
    class FirefoxRemoteViewer
      class MiddlewareTest < TestCase
        setup do
          @app = Middleware.new(
            proc { [200, { "content-type" => "text/plain" }, ["Hello world!"]] },
          )
        end

        test ".id" do
          profile = VernierProfile.new(vernier_profile)
          profile_id = profile.file.basename.to_s

          assert_equal(profile_id, Middleware.id(profile.file))
        end

        test "#call index" do
          profiles = Array.new(3) { VernierProfile.new(vernier_profile).tap(&:file) }

          status, headers, html = call_middleware(@app, Rack::MockRequest.env_for("/app_profiler"))
          html = html.first

          assert_equal(200, status)
          assert_equal({ "content-type" => "text/html" }, headers)
          assert_match(%r(<title>App Profiler</title>), html)
          profiles.each do |profile|
            id = Middleware.id(profile.file)
            assert_match(
              %r(<a href="/app_profiler/firefox/viewer/#{id}">), html
            )
          end
        end

        test "#call index with slash" do
          profiles = Array.new(3) { VernierProfile.new(vernier_profile).tap(&:file) }

          status, headers, html = call_middleware(@app, Rack::MockRequest.env_for("/app_profiler/"))
          html = html.first

          assert_equal(200, status)
          assert_equal({ "content-type" => "text/html" }, headers)
          assert_match(%r(<title>App Profiler</title>), html)
          profiles.each do |profile|
            id = Middleware.id(profile.file)
            assert_match(
              %r(<a href="/app_profiler/firefox/viewer/#{id}">), html
            )
          end
        end

        test "#call show" do
          profile = VernierProfile.new(vernier_profile)
          id = Middleware.id(profile.file)

          status, headers, body = call_middleware(
            @app,
            Rack::MockRequest.env_for("/app_profiler/firefox/#{id}"),
          )

          assert_equal(200, status)
          assert_equal({ "content-type" => "application/json" }, headers)
          assert_equal(JSON.dump(profile.to_h), body.first)
        end

        test "#call viewer sets up yarn" do
          @app.expects(:system).with({}, "which", "yarn", out: File::NULL).returns(true)
          @app.expects(:system).with({}, "yarn", "init", "--yes").returns(true)

          url = "https://github.com/tenderlove/profiler"
          branch = "v0.0.2"
          @app.expects(:system).with({}, "git", "clone", url, "firefox-profiler", "--branch=#{branch}").returns(true)

          File.expects(:read).returns("{}")
          File.expects(:write).returns(true)

          dir = "./tmp"

          @app.expects(:system).with({}, "yarn", "--cwd", "#{dir}/firefox-profiler").returns(true)

          File.expects(:read).with("#{dir}/firefox-profiler/webpack.config.js").returns("")
          File.expects(:write).with("#{dir}/firefox-profiler/webpack.config.js", "").returns(true)

          File.expects(:read).with("#{dir}/firefox-profiler/src/app-logic/l10n.js").returns("")
          File.expects(:write).with("#{dir}/firefox-profiler/src/app-logic/l10n.js", "").returns(true)

          @app.expects(:system).with({}, "yarn", "--cwd", "#{dir}/firefox-profiler", "build-prod").returns(true)

          File.expects(:read).with("#{dir}/firefox-profiler/dist/index.html").returns("")
          File.expects(:write).with("#{dir}/firefox-profiler/dist/index.html", "").returns(true)

          @app.expects(:system).with({}, "yarn", "add", "--dev", "#{dir}/firefox-profiler").returns(true)
          call_middleware(@app, Rack::MockRequest.env_for("/app_profiler/firefox/viewer/index.html"))

          assert_predicate(@app, :yarn_setup)
        end

        test "#call viewer serves static files and Firefox routes" do
          old_root = AppProfiler.root
          Dir.mktmpdir do |directory|
            AppProfiler.root = Pathname.new(directory)
            assets = AppProfiler.root.join("node_modules/firefox-profiler/dist")
            assets.mkpath
            html = "<html>viewer</html>"
            assets.join("index.html").write(html)

            app = Middleware.new(proc { [200, { "content-type" => "text/plain" }, ["Hello world!"]] })
            app.yarn_setup = true
            handler = app.instance_variable_get(:@firefox_profiler)
            app.instance_variable_set(:@firefox_profiler, Rack::Lint.new(handler))

            status, _, body = call_middleware(
              app,
              Rack::MockRequest.env_for("/app_profiler/firefox/viewer/index.html"),
            )
            assert_equal(200, status)
            assert_equal(html, body.join)

            status, _, = call_middleware(
              app,
              Rack::MockRequest.env_for("/app_profiler/firefox/viewer/missing.js"),
            )
            assert_equal(404, status)

            profile = VernierProfile.new(vernier_profile)
            id = Middleware.id(profile.file)
            source = "https://app-profiler.com/app_profiler/firefox/#{id}"
            status, headers, = call_middleware(
              app,
              Rack::MockRequest.env_for(
                "https://app-profiler.com/app_profiler/firefox/viewer/#{id}",
                "HTTP_HOST" => "app-profiler.com",
              ),
            )
            assert_equal(302, status)
            assert_equal("/from-url/#{CGI.escape(source)}", headers["location"])

            status, headers, body = call_middleware(
              app,
              Rack::MockRequest.env_for(
                "https://app-profiler.com/from-url/#{CGI.escape(source)}",
                "HTTP_HOST" => "app-profiler.com",
              ),
            )
            assert_equal(200, status)
            assert_equal("text/html", headers["content-type"])
            assert_equal(html, body.join)
          end
        ensure
          AppProfiler.root = old_root
        end

        test "#call" do
          response = call_middleware(@app, Rack::MockRequest.env_for("/app_level_route"))

          assert_equal([200, { "content-type" => "text/plain" }, ["Hello world!"]], response)
        end
      end
    end
  end
end
