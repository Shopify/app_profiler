# frozen_string_literal: true

require "test_helper"

module AppProfiler
  module Viewer
    class SpeedscopeRemoteViewer
      class MiddlewareTest < TestCase
        setup do
          @app = Middleware.new(
            proc { [200, { "Content-Type" => "text/plain" }, ["Hello world!"]] }
          )
        end

        test ".id" do
          profile = AbstractProfile.from_stackprof(stackprof_profile)
          profile_id = profile.file.basename.to_s

          assert_equal(profile_id, Middleware.id(profile.file))
        end

        test "#call index" do
          profiles = Array.new(3) { AbstractProfile.from_stackprof(stackprof_profile).tap(&:file) }

          code, content_type, html = @app.call({ "PATH_INFO" => "/app_profiler" })
          html = html.first

          assert_equal(200, code)
          assert_equal({ "Content-Type" => "text/html" }, content_type)
          assert_match(%r(<title>App Profiler</title>), html)
          profiles.each do |profile|
            id = Middleware.id(profile.file)
            assert_match(
              %r(<a href="/app_profiler/speedscope/viewer/#{id}">), html
            )
          end
        end

        test "#call index with slash" do
          profiles = Array.new(3) { AbstractProfile.from_stackprof(stackprof_profile).tap(&:file) }

          code, content_type, html = @app.call({ "PATH_INFO" => "/app_profiler/" })
          html = html.first

          assert_equal(200, code)
          assert_equal({ "Content-Type" => "text/html" }, content_type)
          assert_match(%r(<title>App Profiler</title>), html)
          profiles.each do |profile|
            id = Middleware.id(profile.file)
            assert_match(
              %r(<a href="/app_profiler/speedscope/viewer/#{id}">), html
            )
          end
        end

        test "#call show" do
          profile = AbstractProfile.from_stackprof(stackprof_profile)
          id = Middleware.id(profile.file)

          code, content_type, body = @app.call({ "PATH_INFO" => "/app_profiler/speedscope/#{id}" })

          assert_equal(200, code)
          assert_equal({ "Content-Type" => "application/json" }, content_type)
          assert_equal(JSON.dump(profile.to_h), body.first)
        end

        test "#call viewer sets up yarn" do
          @app.expects(:system).with("which", "yarn", out: File::NULL).returns(true)
          @app.expects(:system).with("yarn", "init", "--yes").returns(true)
          @app.expects(:system).with(
            "yarn", "add", "speedscope", "--dev", "--ignore-workspace-root-check"
          ).returns(true)

          @app.call({ "PATH_INFO" => "/app_profiler/speedscope/viewer/index.html" })

          assert_predicate(@app, :yarn_setup)
        end

        test "#call viewer" do
          with_yarn_setup(@app) do
            @app.expects(:speedscope).returns(proc { [200, { "Content-Type" => "text/plain" }, ["Speedscope"]] })

            response = @app.call({ "PATH_INFO" => "/app_profiler/speedscope/viewer/index.html" })

            assert_equal([200, { "Content-Type" => "text/plain" }, ["Speedscope"]], response)
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
