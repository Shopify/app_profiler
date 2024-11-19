# frozen_string_literal: true

module AppProfiler
  module Exec # :nodoc:
    protected

    def valid_commands
      raise NotImplementedError
    end

    def ensure_command_valid(command)
      unless valid_command?(command)
        raise ArgumentError, "Illegal command: #{command.join(" ")}."
      end
    end

    def valid_command?(command)
      valid_commands.any? do |valid_command|
        next unless valid_command.size == command.size

        valid_command.zip(command).all? do |valid_part, part|
          part.match?(valid_part)
        end
      end
    end

    def exec(*command, silent: false, environment: {})
      ensure_command_valid(command)

      if silent
        system(environment, *command, out: File::NULL).tap { |return_code| yield unless return_code }
      else
        system(environment, *command).tap { |return_code| yield unless return_code }
      end
    end
  end
end
