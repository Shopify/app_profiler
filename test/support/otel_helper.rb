# frozen_string_literal: true

require "opentelemetry/instrumentation/rack"

module AppProfiler
  # Helpers for the setups the OpenTelemetry integration supports: opentelemetry-shopify 2.0
  # (OpenTelemetry::Shopify::Instrumentation::Rack), opentelemetry-instrumentation-rack
  # (OpenTelemetry::Instrumentation::Rack, loaded by default in the tests), both, or neither.
  module OtelHelper
    # Defines a stand-in for opentelemetry-shopify 2.0's OpenTelemetry::Shopify::Instrumentation::Rack
    # for the duration of the block. Its current_span returns +span+.
    def with_shopify_rack_instrumentation(span = OpenTelemetry::Trace::Span::INVALID)
      rack = Module.new
      rack.define_singleton_method(:current_span) { |_context = nil| span }
      instrumentation = Module.new
      instrumentation.const_set(:Rack, rack)
      shopify = Module.new
      shopify.const_set(:Instrumentation, instrumentation)

      raise "OpenTelemetry::Shopify is already defined" if OpenTelemetry.const_defined?(:Shopify, false)

      OpenTelemetry.stub_const(:Shopify, shopify) { yield(rack) }
    end

    # Hides opentelemetry-instrumentation-rack's OpenTelemetry::Instrumentation::Rack for the
    # duration of the block.
    def without_contrib_rack_instrumentation(&block)
      OpenTelemetry::Instrumentation.stub_remove_const(:Rack, &block)
    end
  end
end
