# frozen_string_literal: true

require "rack"

module AppProfiler
  class Parameters
    DEFAULT_INTERVALS = { "cpu" => 1000, "wall" => 1000, "object" => 2000 }.freeze
    MIN_INTERVALS = { "cpu" => 200, "wall" => 200, "object" => 400 }.freeze
    MODES = DEFAULT_INTERVALS.keys.freeze

    attr_reader :autoredirect

    def initialize(mode: :wall, interval: nil, ignore_gc: false, autoredirect: false, metadata: {})
      @mode = mode.to_sym
      @interval = [interval&.to_i || DEFAULT_INTERVALS.fetch(@mode.to_s), MIN_INTERVALS.fetch(@mode.to_s)].max
      @ignore_gc = !!ignore_gc
      @autoredirect = autoredirect
      @metadata = { context: AppProfiler.context }.merge(metadata)
    end

    def valid?
      true
    end

    def to_h
      {
        mode: @mode,
        interval: @interval,
        ignore_gc: @ignore_gc,
        metadata: @metadata,
      }
    end
  end
end
