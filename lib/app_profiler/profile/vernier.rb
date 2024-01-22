# frozen_string_literal: true

module AppProfiler
  class VernierProfile < BaseProfile
    FILE_EXTENSION = ".gecko.json"

    def mode
      @data[:meta][:mode]
    end

    def metadata
      @data[:meta]
    end

    def format
      FILE_EXTENSION
    end

    def view(params = {})
      Viewer::FirefoxRemoteViewer.view(self, **params)
    end
  end
end
