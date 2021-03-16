# frozen_string_literal: true

gem("rack")
require "rack"

module AppProfiler
  module Viewer
    class SpeedscopeServerViewer < SpeedscopeViewer
      mattr_accessor :server_started, default: false
      # require 'cgi'
      # require 'fileutils'

      def view
        start_server unless server_started?
        puts "Go to X to view profile."
      end

      private

      def start_server
        self.class.server_started = true
      end
    end
  end
end
