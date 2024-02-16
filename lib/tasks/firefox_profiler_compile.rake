# frozen_string_literal: true

require "rubygems/package"
require "zlib"
require "fileutils"

require "app_profiler"
require "app_profiler/yarn/command"
require "app_profiler/yarn/with_firefox_profiler"

# The bundle is already compiled, so we can ignore most of the source contents
PACKAGE_INCLUDE = [
  /^package\.json$/,
  /^dist/,
].freeze

# Hack to make the package.json more portable by removing some constraints
# contains arrays of diggable hash keys
DELETE_KEYS = [
  ["engines"],
  ["scripts", "preinstall"],
]

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
              fp = File.open(file, "rb")
              fp = prune_keys(fp) if file == "package.json"
              tar.add_file_simple(file, mode, fp.size) do |tar_file|
                IO.copy_stream(fp, tar_file)
              end
              fp.close
            end
          end
        end
      end
    end
  end
end

def prune_keys(orig_fp)
  package_contents = JSON.parse(orig_fp.read)
  orig_fp.close
  DELETE_KEYS.each do |keys|
    next unless package_contents.dig(*keys)

    to_delete = keys.pop
    if keys.empty?
      package_contents.delete(to_delete)
    else
      nested_hash = package_contents.dig(*keys)
      nested_hash.delete(to_delete)
    end
  end
  tmp = Tempfile.new("relaxed_package.json")
  tmp.unlink
  tmp.write(JSON.dump(package_contents))
  tmp.flush
  tmp.rewind
  tmp
end
