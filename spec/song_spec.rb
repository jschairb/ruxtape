require 'ruxtape'
require 'spec'

describe Song do 

  before do 
    @filename = "06 Pop Goes the Weasel.mp3"
  end

  it "returns a new song" do 
    Song.new("foo.mp3").should be_kind_of(Song)
  end

  it "has the correct path" do 
    path = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs').gsub("spec/", "")
    Song::MP3_PATH.should == path
  end

  # describe "#delete" do 
  # end

  describe "#find" do 
    before do 
      @song = Song.find(@filename)
    end

    it "returns a Song" do 
      @song.should be_kind_of(Song)
    end

    it "loads Mp3Info data" do 
      @song.artist.should == "10,000 Maniacs"
    end
  end

  # describe "#new" do 
  # end

  # describe "#path" do 
  # end

  describe "#time" do 
    it "ensures 00:00" do 
      song = Song.find(@filename)
      song.time.should match(/^\d{1,}:\d{2}/) 
    end
  end

  describe "#update" do 
    it "finds a song" do 
      song = Song.find(@filename)
      song.update(:artist => "10,000 Maniacs", :title => "Cherry Tree")
    end
  end

end
