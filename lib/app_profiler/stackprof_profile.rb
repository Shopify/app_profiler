# frozen_string_literal: true

module AppProfiler
  class StackprofProfile < BaseProfile
    FILE_EXTENSION = ".stackprof.json"

    class << self
      def backend_name
        Backend::StackprofBackend.name.to_s
      end
    end

    def initialize(data, id: nil, context: nil)
      data[:metadata] ||= {}
      super(data, id: id, context: context)
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
