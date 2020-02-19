# frozen_string_literal: true

module AppProfiler
  module Viewer
    class BaseViewer
      def self.view(_profile)
        raise NotImplementedError
      end
    end
  end
end
