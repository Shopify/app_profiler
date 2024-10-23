# frozen_string_literal: true

module AppProfiler
  module Viewer
    class BaseViewer
      class << self
        def view(profile, params = {})
          new(profile).view(**params)
        end
      end
    end
  end
end
