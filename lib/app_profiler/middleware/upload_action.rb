# frozen_string_literal: true

module AppProfiler
  class Middleware
    class UploadAction < BaseAction
      class << self
        def call(profile, response: nil, autoredirect: nil, async: false)
          if async
            profile.enqueue_upload
            response[1][AppProfiler.profile_async_header] = "true"
          else
            profile_upload = profile.upload

            append_headers(
              response,
              upload: profile_upload,
              autoredirect: autoredirect.nil? ? AppProfiler.autoredirect : autoredirect
            ) if response
          end
        end

        private

        def append_headers(response, upload:, autoredirect:)
          return unless upload

          response[1][profile_header]      = AppProfiler.profile_url(upload)
          response[1][profile_data_header] = profile_data_url(upload)

          return unless autoredirect

          # Automatically redirect to profile if autoredirect is true.
          location = AppProfiler.profile_url(upload)
          if response[0].to_i < 500 && location
            response[1]["Location"] = location
            response[0] = 303
          end
        end

        def profile_data_url(upload)
          upload.url.to_s
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
