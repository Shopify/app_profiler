# frozen_string_literal: true

require "rubygems/package"
require "zlib"
require "fileutils"

require "app_profiler"
require "app_profiler/yarn/command"
require "app_profiler/yarn/with_firefox_profiler"

# The bundle is already compiled, so we can ignore most of the source contents
PACKAGE_INCLUDE = [
  %r{^\.circleci/config\.yml$},
  %r{^bin/pre-install\.js$},
  /^package\.json$/,
  /^dist/,
].freeze

class CompileShim
  include AppProfiler::Yarn::WithFirefoxProfile
end

namespace :firefox_profiler do
  desc "Compile firefox profiler"
  task :compile do
    AppProfiler.root = Pathname.getwd
    CompileShim.new.setup_yarn
  end
  desc "Package firefox profiler"
  task package: :compile do
    package_directory("node_modules/firefox-profiler", "out.tar.gz")
  end
end

def package_directory(source_dir, output)
  File.open(output, "wb") do |tar_gz_file|
    Zlib::GzipWriter.wrap(tar_gz_file) do |gzip_file|
      Dir.chdir(source_dir) do
        Gem::Package::TarWriter.new(gzip_file) do |tar|
          Dir["**/*", ".*/**/*"].each do |file|
            next unless PACKAGE_INCLUDE.any? { |pattern| file =~ pattern }

            mode = File.stat(file).mode

            if File.directory?(file)
              tar.mkdir(file, mode)
            else
              tar.add_file_simple(file, mode, File.size(file)) do |tar_file|
                IO.copy_stream(File.open(file, "rb"), tar_file)
              end
            end
          end
        end
      end
    end
  end
end
