# frozen_string_literal: true

require "securerandom"
require "active_support/isolated_execution_state"
require "active_support/code_generator"
require "active_support/current_attributes"

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
