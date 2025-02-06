# frozen_string_literal: true

module AppProfiler
  class StackprofProfile < BaseProfile
    FILE_EXTENSION = ".stackprof.json"

    def initialize(data, id: nil, context: nil)
      super(data, id: id, context: context)
      @data[:metadata] ||= {}
      metadata[PROFILE_BACKEND_METADATA_KEY] = Backend::StackprofBackend.name.to_s
      metadata[PROFILE_ID_METADATA_KEY] = id
    end

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
