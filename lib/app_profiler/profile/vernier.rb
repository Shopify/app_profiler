# frozen_string_literal: true

module AppProfiler
  class VernierProfile < AbstractProfile
    FILE_EXTENSION = ".gecko.json"

    def mode
      @data[:meta][:mode]
    end

    def format
      FILE_EXTENSION
    end

    def view(params = {})
      Viewer::FirefoxViewer.view(self, **params)
    end
  end
end
