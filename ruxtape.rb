#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + "/lib"
%w(camping mime/types mp3info).each { |lib| require lib}

Camping.goes :Ruxtape

module Ruxtape::Models
  class Song
    attr_accessor :title, :artist, :length
    def initialize(path) 
      @path = path 
      Mp3Info.open(@path) do |mp3|
        self.title, self.artist, self.length = mp3.tag.title, mp3.tag.artist, mp3.length
      end
    end
    def self.ruxtape
      path = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs')
      songs = []
      Dir.glob("#{path}/*.mp3").each { |mp3| songs << Song.new(mp3)}
      return songs
    end
    def time
      minutes = (length/60).to_i; seconds = (((length/60) - minutes) * 60).to_i
      time = "#{minutes}:#{seconds}"
      return time
    end
  end
end

module Ruxtape::Controllers
  class Index < R '/'
    def get
      setup = true
      if setup
        @songs = Song.ruxtape
        render :index
      else
        render :setup
      end
    end
  end

  class Static < R '/assets/(.+)'         
    MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript'}
    PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public')

    def get(path)
      @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
      unless path.include? ".." # prevent directory traversal attacks
        file = "#{PATH}/assets/#{path}"
        @headers['X-Sendfile'] = "#{PATH}/assets/#{path}"
      else
        @status = "403"
        "403 - Invalid path"
      end
    end
  end

end

module Ruxtape::Views
  def layout
    html do 
      head do 
        title "Ruxtape"
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/styles.css', :media => 'screen' )
      end
      body do 
        div.wrapper! do 
          div.header! do 
            div.title! { "Ruxtape, sucka"} 
            div.subtitle! {"1 songs, 1 min 47 secs"}
          end
          div.content! do 
            self << yield
          end
          div.footer! { "Ruxtape 0.1"}
        end
      end
    end
  end

  def index 
    ul.songs do 
      @songs.each do |song|
        li.song do 
          div.name "#{song.artist} - #{song.title}"
          div.clock { }
          strong song.time
        end
      end
    end
  end

  def setup
    h1 "Get Mixin'"
    p "Create a password for the admin sections."
    p "TODO: a form goes here."
  end
end
