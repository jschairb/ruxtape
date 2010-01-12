class Song
  MP3_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', 'public', 'songs'))

  attr_accessor :title, :artist, :length, :tracknum, :filename

  def self.all
    songs = []
    Dir.glob("#{MP3_PATH}/*.mp3") { |song| songs << Song.find(File.basename(song)) }
    return songs.any? ? songs.sort : []
  end

  def self.find(filename)
    song = Song.new(filename, false)
    return song
  end

  def initialize(filename,new_record=true)
    @filename = filename
    @new_record = new_record
    unless new_record?
      _get_mp3_info
    end
  end

  def <=>(other)
    self.tracknum.to_i <=> other.tracknum.to_i
  end

  def delete
    File.delete(self.path)
  end

  def filename
    File.basename(self.path)
  end

  def new_record?
    @new_record
  end
  
  def path
    File.join(MP3_PATH, @filename)
  end

  def save
  end

  def time
    minutes = (length/60).to_i; seconds = (((length/60) - minutes) * 60).to_i
    "#{minutes}:#{seconds}"
  end

  def update(attributes)
    attributes = attributes.delete_if { |key,value| value.nil? || value == "" }
    Mp3Info.open(path) do |mp3|
      mp3.tag.title = attributes[:title]
      mp3.tag.artist = attributes[:artist]
      mp3.tag.tracknum = attributes[:tracknum].to_i
    end
  end

  def _get_mp3_info
    Mp3Info.open(path) do |mp3|
      %w(title artist tracknum).each do |attr|
        self.send("#{attr}=", mp3.tag.send(attr.intern))
      end
      self.length = mp3.length
    end
  end
end
