# frozen_string_literal: true

module AppProfiler
  module Viewer
    class BaseViewer
      class << self
        def view(profile, params = {})
          new(profile).view(**params)
        end

        def remote?
          false
        end
      end
    end
  end
end
