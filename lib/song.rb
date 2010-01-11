class Song

  attr_accessor :title, :artist, :length, :tracknum

  def initialize(path)
    @path = path
    _get_mp3_info
  end

  def <=>(other)
    self.tracknum <=> other.tracknum
  end

  def delete
    File.delete(@path)
  end

  def filename
    File.basename(@path)
  end

  def time
    minutes = (length/60).to_i; seconds = (((length/60) - minutes) * 60).to_i
    "#{minutes}:#{seconds}"
  end

  def update(attributes)
    Mp3Info.open(self.path) do |song|
      mp3.tag.title = attributes[:title]
      mp3.tag.artist = attributes[:artist]
      mp3.tag.tracknum = attributes[:tracknum].to_i
    end
  end

  def _get_mp3_info
    Mp3Info.open(@path) do |mp3|
      %w(title artist tracknum).each do |attr|
        self.send("#{attr}=", mp3.tag.send(attr.intern))
      end
      self.length = mp3.length
    end
  end
end
