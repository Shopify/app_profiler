# frozen_string_literal: true

module AppProfiler
  class StackprofProfile < AbstractProfile
    FILE_EXTENSION = ".stackprof.json"

    def mode
      @data[:mode]
    end

    def format
      FILE_EXTENSION
    end

    def view(params = {})
      Viewer::SpeedscopeViewer.view(self, **params)
    end
  end
end
