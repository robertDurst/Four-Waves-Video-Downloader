require_relative 'four_wave_video_downloader'

puts 'Enter your FourWave username:'
username = gets.chomp

puts 'Enter your FourWave password:'
password = gets.chomp

# Initialize the FourWaveVideoDownloader
downloader = FourWaveVideoDownloader.new(username: username, password: password)

# Run the download_all method
downloader.download_all
