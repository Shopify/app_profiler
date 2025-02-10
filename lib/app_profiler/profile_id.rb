# frozen_string_literal: true

require "securerandom"

module AppProfiler
  class ProfileId
    class Current
      PROFILE_ID_KEY = :__app_profiler_profile_id__
      class << self
        # This is a thread local variable which gets reset by the middleware at the end of the request.
        # Need to be mindful of the middleware order. If we try to access ProfileId after the middleware has finished,
        # lets say in a middleware which runs before Profiling middleware, it will return a different value,
        # as the middleware has already reset.

        def id
          Thread.current[PROFILE_ID_KEY] ||= SecureRandom.hex
        end

        def id=(id)
          Thread.current[PROFILE_ID_KEY] = id
        end

        def reset
          Thread.current[PROFILE_ID_KEY] = nil
        end
      end
    end

    class << self
      def current
        Current.id
      end

      def current=(id)
        Current.id = id
      end
    end
  end
end
