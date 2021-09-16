# frozen_string_literal: true
module AppProfiler
  module Yarn
    module WithSpeedscope
      include Command

      def setup_yarn
        super
        # We currently only support this gem in the root Gemfile.
        # See https://github.com/Shopify/app_profiler/issues/15
        # for more information
        yarn("add", "speedscope", "--dev", "--ignore-workspace-root-check") unless speedscope_added?
      end

      private

      def speedscope_added?
        AppProfiler.root.join("node_modules/speedscope").exist?
      end
    end
  end
end
