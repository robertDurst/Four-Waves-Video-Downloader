require 'httparty'
require 'json'
require 'open-uri'

class FourWaveVideoDownloader
  def initialize(username:, password:, download_path: 'videos')
    @auth_token = login(username, password)
    @download_path = download_path
    @events = fetch_events

    puts "Found #{events.size} events:"
    events.select! do |event|
      puts "Event: #{event[:name]}"
      puts 'Do you want to download videos from this event? (y/n)'
      gets.chomp == 'y'
    end
  end

  # Download all videos from a session
  # @param auth_token [String] the auth token
  def download_all
    puts "Downloading videos from #{events.size} event(s):"
    events.each { |event| puts "- #{event[:name]}" }

    mkdir_p(download_path)

    events.each do |event|
      puts "Event: #{event[:name]}"
      response = HTTParty.get("https://api.fourwaves.com/api/events/#{event[:id]}/sessions",
                              headers: { 'Authorization' => "Bearer #{auth_token}" })

      mkdir_p("#{download_path}/#{event[:name]}")

      all_sessions_with_videos = JSON.parse(response.body)['data'].map { |session| format_session(session) }.compact

      all_sessions_with_videos.each_with_index do |session, i|
        log_progress(all_sessions_with_videos.size, i, "Downloading #{session[:file_path]}...")

        download_video(session[:recorded_video_url], "#{download_path}/#{event[:name]}/#{session[:file_path]}")

        log_progress(all_sessions_with_videos.size, i, "Downloaded #{session[:file_path]}")
      end
    end
  end

  private

  attr_reader :auth_token, :download_path
  attr_accessor :events

  ### Helper methods ###
  def log_progress(is, i, message)
    puts "[#{i + 1}/#{is}] #{message}"
  end

  def mkdir_p(file_path)
    Dir.mkdir(file_path) unless Dir.exist?(file_path)
  end
  ######################

  ### API methods ###
  def login(username, password)
    response = HTTParty.post(
      'https://api.fourwaves.com/api/auth/login',
      headers: { 'Content-Type' => 'application/json' },
      body: { email: username, password: password }.to_json
    )

    raise "Failed to authenticate: #{response.body}" if response.code != 200

    JSON.parse(response.body)['token']
  end

  def fetch_events
    url = 'https://api.fourwaves.com/v1.0/events?status=all&userRoles=PARTICIPANT&userRoles=SUBMITTER&userRoles=AUTHOR'

    response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{auth_token}" })

    JSON.parse(response.body)['items'].map { |event| { id: event['id'], name: event['name']['en'] } }
  end
  ######################

  ### Format and download methods ###
  def format_session(session)
    return nil unless session['recordedVideo']

    session_title = session['title']['en'].gsub(/[^0-9A-Za-z.-]/, '_')
    session_time_formatted = "#{session['startDate']}-#{session['endDate']}".gsub(/[^0-9A-Za-z.-]/, '_')

    {
      file_path: "#{session_time_formatted}_#{session_title}.mp4",
      recorded_video_url: session['recordedVideo']['url']
    }
  end

  def download_video(url, file_path)
    URI.open(url) do |video|
      File.open(file_path, 'wb') do |file|
        file.write(video.read)
      end
    end
  end
  ###################################
end
