class Mixtape
  MP3_PATH = File.join(File.expand_path(File.dirname(__FILE__)), '..','public', 'songs')

  def songs
    songs = []
    Dir.glob("#{MP3_PATH}/*.mp3") { |song| songs << Song.new(song) }
    return songs
  end

  def length
    minutes, seconds = 0,0
    self.songs.each { |song| time = song.time.split(':'); minutes += time[0].to_i; seconds += time[1].to_i }
    sec_minutes = (seconds/60).to_i
    minutes += sec_minutes; seconds =  seconds - (sec_minutes*60)
    seconds = "0#{seconds}" if seconds.to_s.size == 1
    "#{minutes}:#{seconds}"
  end
end
