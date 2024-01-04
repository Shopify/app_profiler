# frozen_string_literal: true

module AppProfiler
  module Yarn
    module WithFirefoxProfile
      include Command

      def setup_yarn
        super
        return if firefox_profiler_added?

        yarn("add", "https://github.com/Shopify/firefox-profiler")
        yarn("--cwd", "node_modules/firefox-profiler")
      end

      private

      def firefox_profiler_added?
        AppProfiler.root.join("node_modules/firefox-profiler").exist?
      end
    end
  end
end
