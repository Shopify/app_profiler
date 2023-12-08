# frozen_string_literal: true

module AppProfiler
  class Middleware
    class ViewAction < BaseAction
      class << self
        def call(profile, params = {})
          profile.view(**params)
        end
      end
    end
  end
end
