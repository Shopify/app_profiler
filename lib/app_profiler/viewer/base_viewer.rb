# frozen_string_literal: true

module AppProfiler
  module Viewer
    class BaseViewer
      class << self
        def view(profile)
          new(profile).view
        end
      end

      def view(_profile)
        raise NotImplementedError
      end
    end
  end
end
