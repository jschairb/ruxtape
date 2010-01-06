class Song

  attr_accessor :title, :artist, :length, :tracknum

  def initialize(path)
    @path = path
    _get_mp3_info
  end

  def filename
    File.basename(@path)
  end

  def time
    minutes = (length/60).to_i; seconds = (((length/60) - minutes) * 60).to_i
    "#{minutes}:#{seconds}"
  end

  def url_path
    "/songs/#{URI.escape(File.basename(@path))}"
  end

  def _get_mp3_info
    Mp3Info.open(@path) do |mp3|
      %w(title artist length tracknum).each do |attr|
        self.send("#{attr}=", mp3.tag.send(attr.intern))
      end
    end
  end

end
