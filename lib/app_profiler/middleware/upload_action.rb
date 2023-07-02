# frozen_string_literal: true

module AppProfiler
  class Middleware
    class UploadAction < BaseAction
      class << self
        def call(profile, response: nil, autoredirect: nil, async: false)
          if async
            enqueue_upload(profile)
            response[1][AppProfiler.profile_async_header] = true
            return
          end

          profile_upload = profile.upload
          return unless response

          append_headers(
            response,
            upload: profile_upload,
            autoredirect: autoredirect.nil? ? AppProfiler.autoredirect : autoredirect
          )
        end

        def enqueue_upload(profile)
          mutex.synchronize do
            @queue ||= init_queue
            begin
              @queue.push(profile, true) # non-blocking push, raises ThreadError if queue is full
            rescue ThreadError
              AppProfiler.logger.info("[AppProfiler] upload queue is full, profile discarded")
            end
          end
        end

        def start_process_queue_thread
          @process_queue_thread ||= Thread.new do
            loop do
              process_queue
              sleep(AppProfiler.upload_queue_interval_secs)
            end
          end
          @process_queue_thread.priority = -1 # low priority
        end

        private

        def mutex
          @mutex ||= Mutex.new
        end

        def init_queue
          @queue = SizedQueue.new(AppProfiler.upload_queue_max_length)
        end

        def process_queue
          queue = nil
          mutex.synchronize do
            break if @queue.nil? || @queue.empty?

            queue = @queue
            init_queue
          end

          return 0 unless queue

          size = queue.length
          size.times { queue.pop(false).upload }

          size
        end

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
