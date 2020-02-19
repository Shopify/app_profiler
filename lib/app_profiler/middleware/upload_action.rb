# frozen_string_literal: true

module AppProfiler
  class Middleware
    class UploadAction < BaseAction
      class << self
        def call(profile, response: nil, autoredirect: nil)
          profile_upload = profile.upload

          return unless response

          append_headers(
            response,
            upload: profile_upload,
            autoredirect: autoredirect.nil? ? AppProfiler.autoredirect : autoredirect
          )
        end

        private

        def append_headers(response, upload:, autoredirect:)
          return unless upload

          response[1][profile_header]      = profile_url(upload)
          response[1][profile_data_header] = profile_data_url(upload)

          return unless autoredirect

          # Automatically redirect to profile if autoredirect is true.
          if response[0].to_i < 500
            response[1]["Location"] = profile_url(upload)
            response[0] = 303
          end
        end

        def profile_url(upload)
          "#{AppProfiler.speedscope_host}#profileURL=#{upload.url}"
        end

        def profile_data_url(upload)
          upload.url
        end

        def profile_header
          AppProfiler.profile_header
        end

        def profile_data_header
          AppProfiler.profile_data_header
        end
      end
    end
  end
end
