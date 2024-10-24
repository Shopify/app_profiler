# frozen_string_literal: true

module AppProfiler
  class StackprofProfile < BaseProfile
    FILE_EXTENSION = ".json"

    def mode
      @data[:mode]
    end

    def metadata
      @data[:metadata]
    end

    def format
      FILE_EXTENSION
    end

    def view(params = {})
      AppProfiler.stackprof_viewer.view(self, **params)
    end
  end
end
