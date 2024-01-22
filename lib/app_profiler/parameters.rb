# frozen_string_literal: true

require "rack"

module AppProfiler
  class Parameters
    DEFAULT_INTERVALS = { "cpu" => 1000, "wall" => 1000, "object" => 2000, "retained" => 0 }.freeze
    MIN_INTERVALS = { "cpu" => 200, "wall" => 200, "object" => 400, "retained" => 0 }.freeze

    attr_reader :autoredirect, :async, :backend

    def initialize(mode: :wall, interval: nil, ignore_gc: false, autoredirect: false,
      async: false, backend: nil, metadata: {})
      @mode = mode.to_sym
      @interval = [interval&.to_i || DEFAULT_INTERVALS.fetch(@mode.to_s), MIN_INTERVALS.fetch(@mode.to_s)].max
      @ignore_gc = !!ignore_gc
      @autoredirect = autoredirect
      @backend = backend
      @metadata = { context: AppProfiler.context }.merge(metadata)
      @async = async
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
