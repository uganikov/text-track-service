# frozen_string_literal: true

require 'connection_pool'
require 'faktory'

module TTS
  class UtilWorker # rubocop:disable Style/Documentation
    include Faktory::Job
    faktory_options retry: 5, concurrency: 1
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    def perform(params)
      data = JSON.load params
      record_id = data['record_id']
      storage_dir = data['storage_dir']
      temp_track_vtt = data['temp_track_vtt']
      temp_track_json = data['temp_track_json']
      myarray = data['myarray']
      current_time = data['current_time']
      caption_locale = data['caption_locale']
      id = data['database_id']
      bbb_url = data['bbb_url']
      bbb_checksum = data['bbb_checksum']

      u = Caption.find(id)
      ActiveRecord::Base.connection_pool.with_connection do
        # u = Caption.find(id)
        u.update(status: "writing subtitle file from #{u.service}")
      end

      SpeechToText::Util.write_to_webvtt(
        vtt_file_path: storage_dir.to_s,
        vtt_file_name: temp_track_vtt.to_s,
        myarray: myarray
      )

      SpeechToText::Util.recording_json(
        file_path: storage_dir.to_s,
        record_id: record_id,
        timestamp: current_time,
        language: data[:caption_locale]
      )

      ActiveRecord::Base.connection_pool.with_connection do
        u.update(status: "done with #{u.service}")
      end

      data = {
        'record_id' => record_id.to_s,
        'storage_dir' => storage_dir,
        'current_time' => current_time,
        'caption_locale' => caption_locale,
        'bbb_url' => bbb_url,
        'bbb_checksum' => bbb_checksum,
        'temp_dir' => temp_dir
      }

      TTS::CallbackWorker.perform_async(data.to_json)
    end
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
  end
end
