# frozen_string_literal: true

module AppProfiler
  class VernierProfile < BaseProfile
    FILE_EXTENSION = ".vernier.json"
    BACKEND_NAME = :vernier

    class << self
      def backend_name
        # cannot reference Backend::VernierBackend because of different ruby versions we have to support
        BACKEND_NAME.to_s
      end
    end

    def initialize(data, id: nil, context: nil)
      data[:meta] ||= {}
      super(data, id: id, context: context)
    end

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
      AppProfiler.vernier_viewer.view(self, **params)
    end
  end
end
