# frozen_string_literal: true

module AppProfiler
  class Middleware
    class BaseAction
      class << self
        def call(_profile, _params = {})
          raise NotImplementedError
        end

        def cleanup
          profile = AppProfiler.profiler.results
          call(profile) if profile
        end
      end
    end
  end
end
