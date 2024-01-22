# frozen_string_literal: true

module AppProfiler
  class StackprofProfile < Profile
    FILE_EXTENSION = ".stackprof.json"

    delegate :[], to: :@data

    def file
      @file ||= path.tap do |p|
        p.dirname.mkpath
        p.write(JSON.dump(@data))
      end
    end

    def to_h
      @data
    end

    def valid?
      mode.present?
    end

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
