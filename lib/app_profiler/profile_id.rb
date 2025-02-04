# frozen_string_literal: true

require "active_support/current_attributes"
require "securerandom"

module AppProfiler
  class ProfileId
    class Current < ActiveSupport::CurrentAttributes
      attribute :id
    end

    class << self
      def current
        Current.id ||= SecureRandom.hex
        Current.id
      end
    end
  end
end
