# frozen_string_literal: true

module AppProfiler
  class VernierProfile < Profile
    FILE_EXTENSION = ".gecko.json"

    delegate :[], to: :@meta

    attr_reader :data

    def initialize(data, id: nil, context: nil)
      @meta = data.meta
      super
    end

    # https://github.com/jhawthorn/vernier/blob/main/lib/vernier/result.rb#L27-L29
    def file
      @file ||= path.tap do |p|
        p.dirname.mkpath
        @data.write(out: p)
      end
    end

    def valid?
      !@data.nil?
    end

    def to_h
      @data.to_h
    end

    def mode
      @meta[:mode]
    end

    def format
      FILE_EXTENSION
    end

    def view(params = {})
      raise NotImplementedError
    end
  end
end
