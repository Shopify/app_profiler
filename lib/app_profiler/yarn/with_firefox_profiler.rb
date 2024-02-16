# frozen_string_literal: true

require "rubygems/package"
require "zlib"
require "open-uri"

module AppProfiler
  module Yarn
    module WithFirefoxProfile
      include Command
      class CommandError < StandardError; end

      INSTALL_DIRECTORY = "./tmp"

      def setup_yarn
        super
        return if firefox_profiler_added?

        fetch_firefox_profiler
      end

      private

      def firefox_profiler_added?
        AppProfiler.root.join("node_modules/firefox-profiler/dist").exist?
      end

      def github_source?
        AppProfiler.gecko_viewer_package.start_with?("https://github.com")
      end

      def compiled_source?
        AppProfiler.gecko_viewer_package.start_with?("https://") &&
          AppProfiler.gecko_viewer_package.end_with?("_compiled.tar.gz")
      end

      def append_auth_header(opts)
        if AppProfiler.gecko_viewer_package.start_with?("https://storage.googleapis.com/")
          exec("which", "gcloud", silent: true) do
            raise(
              CommandError,
              <<~MSG.squish
                `gcloud` command not found, but gcloud auth required.
                Please install `gcloud` or make it available in PATH.
              MSG
            )
          end

          opts["Authorization"] = "Bearer " + %x(gcloud auth print-access-token)
        end
      end

      def fetch_firefox_profiler
        dir = INSTALL_DIRECTORY

        if github_source?
          fetch_from_github(dir)
        elsif compiled_source?
          fetch_pre_compiled("#{dir}/firefox-profiler")
        else
          raise ArgumentError, "#{AppProfiler.gecko_viewer_package} is not a valid source for firefox profiler"
        end

        yarn("add", "--dev", "#{dir}/firefox-profiler")
      end

      def fetch_pre_compiled(dir)
        opts = {}
        append_auth_header(opts)
        tar_gz_file = URI.parse(AppProfiler.gecko_viewer_package).open(opts)

        Gem::Package::TarReader.new(Zlib::GzipReader.open(tar_gz_file)) do |tar|
          tar.each do |entry|
            next if entry.directory?

            target_file = File.join(dir, entry.full_name)

            FileUtils.mkdir_p(File.dirname(target_file))

            File.open(target_file, "wb") do |f|
              f.write(entry.read)
            end
          end
        end
      end

      def fetch_from_github(dir)
        repo, branch = AppProfiler.gecko_viewer_package.to_s.split("#")

        FileUtils.mkdir_p(dir)
        Dir.chdir(dir) do
          clone_args = ["git", "clone", repo, "firefox-profiler"]
          clone_args.push("--branch=#{branch}") unless branch.nil? || branch&.empty?
          system(*clone_args)
          package_contents = File.read("firefox-profiler/package.json")
          package_json = JSON.parse(package_contents)
          package_json["name"] ||= "firefox-profiler"
          package_json["version"] ||= "0.0.1"
          File.write("firefox-profiler/package.json", package_json.to_json)
        end
        yarn("--cwd", "#{dir}/firefox-profiler")

        patch_firefox_profiler(dir)
        yarn("--cwd", "#{dir}/firefox-profiler", "build-prod")
        patch_file("#{dir}/firefox-profiler/dist/index.html", 'href="locales/en-US/app.ftl"',
          'href="/app_profiler/firefox/viewer/locales/en-US/app.ftl"')
      end

      def patch_firefox_profiler(dir)
        # Patch the publicPath so that the app can be "mounted" at the right location
        patch_file("#{dir}/firefox-profiler/webpack.config.js", "publicPath: '/'",
          "publicPath: '/app_profiler/firefox/viewer/'")
        patch_file("#{dir}/firefox-profiler/src/app-logic/l10n.js", "fetch(`/locales/",
          "fetch(`/app_profiler/firefox/viewer/locales/")
      end

      def patch_file(file, find, replace)
        contents = File.read(file)
        new_contents = contents.gsub(find, replace)
        File.write(file, new_contents)
      end
    end
  end
end
