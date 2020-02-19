# frozen_string_literal: true

module AppProfiler
  class Middleware
    class ViewAction < BaseAction
      class << self
        def call(profile, _params = {})
          profile.view
        end
      end
    end
  end
end
