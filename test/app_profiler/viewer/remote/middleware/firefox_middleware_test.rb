# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class FirefoxRemoteViewer
      class MiddlewareTest < TestCase
        setup do
          @app = Middleware.new(
            proc { [200, { "Content-Type" => "text/plain" }, ["Hello world!"]] }
          )
        end

        test ".id" do
          profile = VernierProfile.new(vernier_profile)
          profile_id = profile.file.basename.to_s

          assert_equal(profile_id, Middleware.id(profile.file))
        end

        test "#call index" do
          profiles = Array.new(3) { VernierProfile.new(vernier_profile).tap(&:file) }

          code, content_type, html = @app.call({ "PATH_INFO" => "/app_profiler" })
          html = html.first

          assert_equal(200, code)
          assert_equal({ "Content-Type" => "text/html" }, content_type)
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

          code, content_type, html = @app.call({ "PATH_INFO" => "/app_profiler/" })
          html = html.first

          assert_equal(200, code)
          assert_equal({ "Content-Type" => "text/html" }, content_type)
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

          code, content_type, body = @app.call({ "PATH_INFO" => "/app_profiler/firefox/#{id}" })

          assert_equal(200, code)
          assert_equal({ "Content-Type" => "application/json" }, content_type)
          assert_equal(JSON.dump(profile.to_h), body.first)
        end

        test "#call viewer sets up yarn" do
          @app.expects(:system).with("which", "yarn", out: File::NULL).returns(true)
          @app.expects(:system).with("yarn", "init", "--yes").returns(true)

          url, branch = AppProfiler.gecko_viewer_package.split("#")
          @app.expects(:system).with("git", "clone", url, "firefox-profiler", "--branch=#{branch}").returns(true)

          File.expects(:read).returns("{}")
          File.expects(:write).returns(true)

          dir = "./tmp"

          @app.expects(:system).with("yarn", "--cwd", "#{dir}/firefox-profiler").returns(true)

          File.expects(:read).with("#{dir}/firefox-profiler/webpack.config.js").returns("")
          File.expects(:write).with("#{dir}/firefox-profiler/webpack.config.js", "").returns(true)

          File.expects(:read).with("#{dir}/firefox-profiler/src/app-logic/l10n.js").returns("")
          File.expects(:write).with("#{dir}/firefox-profiler/src/app-logic/l10n.js", "").returns(true)

          @app.expects(:system).with("yarn", "--cwd", "#{dir}/firefox-profiler", "build-prod").returns(true)

          File.expects(:read).with("#{dir}/firefox-profiler/dist/index.html").returns("")
          File.expects(:write).with("#{dir}/firefox-profiler/dist/index.html", "").returns(true)

          @app.expects(:system).with("yarn", "add", "--dev", "#{dir}/firefox-profiler").returns(true)
          @app.call({ "PATH_INFO" => "/app_profiler/firefox/viewer/index.html" })

          assert_predicate(@app, :yarn_setup)
        end

        test "#call viewer" do
          with_yarn_setup(@app) do
            @app.expects(:firefox_profiler).returns(proc { [200, { "Content-Type" => "text/plain" }, ["Firefox"]] })

            response = @app.call({ "PATH_INFO" => "/app_profiler/firefox/viewer/index.html" })

            assert_equal([200, { "Content-Type" => "text/plain" }, ["Firefox"]], response)
          end
        end

        test "#call" do
          response = @app.call({ "PATH_INFO" => "/app_level_route" })

          assert_equal([200, { "Content-Type" => "text/plain" }, ["Hello world!"]], response)
        end
      end
    end
  end
end
