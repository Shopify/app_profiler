# frozen_string_literal: true

module AppProfiler
  class VernierProfile < BaseProfile
    FILE_EXTENSION = ".gecko.json"

    def mode
      @data[:meta][:mode]
    end

    def format
      FILE_EXTENSION
    end

    def view(params = {})
      raise NotImplementedError
    end
  end
end
