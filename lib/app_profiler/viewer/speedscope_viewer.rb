# frozen_string_literal: true

require "app_profiler/yarn/command"
require "app_profiler/yarn/with_speedscope"

module AppProfiler
  module Viewer
    class SpeedscopeViewer < BaseViewer
      include Yarn::WithSpeedscope

      class << self
        def view(profile, params = {})
          new(profile).view(**params)
        end
      end

      def initialize(profile)
        super()
        @profile = profile
      end

      def view(_params = {})
        yarn("run", "speedscope", @profile.file.to_s)
      end
    end
  end
end
