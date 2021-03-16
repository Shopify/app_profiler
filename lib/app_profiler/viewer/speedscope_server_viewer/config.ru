# frozen_string_literal: true

require_relative "server"

run(AppProfiler::Viewer::SpeedscopeServerViewer::Server.new)
