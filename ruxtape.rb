#!/usr/bin/env ruby
# -*- coding: iso-8859-1 -*-
$:.unshift File.dirname(__FILE__) + "/vendor"
$:.unshift File.dirname(__FILE__) + "/lib"
%w(camping camping_addons fileutils mime/types mp3info yaml openid base64).each { |lib| require lib}

Camping.goes :Ruxtape

module Ruxtape
  include Camping::CookieSessions
  MP3_PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs')
  @@state_secret = "27c9436319ae7c1e760dbd344de08f82b4c7cfcf"
end

module Ruxtape::Models
  class Config
    CONFIG_FILE = File.join(File.expand_path(File.dirname(__FILE__)), 'config', 'config.yml')
    class << self
      def delete; File.delete(CONFIG_FILE); Mixtape.delete; end
      def setup?; return true if File.exist?(CONFIG_FILE) end
      def values; YAML.load_file(CONFIG_FILE); end
      def setup(openid)  
        File.open(CONFIG_FILE, "w") { |f| YAML.dump(openid, f) }
      end
    end
  end

  class Mixtape
    class << self
    def delete
      Dir.glob("#{Ruxtape::MP3_PATH}/*.mp3").each { |mp3| File.delete(mp3) }
    end
    def playlist
      songs = []
      Dir.glob("#{Ruxtape::MP3_PATH}/*.mp3").each { |mp3| songs << Song.new(mp3) }
      return songs
    end
    def song_count; Dir.glob("#{Ruxtape::MP3_PATH}/*.mp3").length; end
    def length 
      minutes, seconds = 0,0
      self.playlist.each { |song| time = song.time.split(':'); minutes += time[0].to_i; seconds += time[1].to_i }
      sec_minutes = (seconds/60).to_i
      minutes += sec_minutes; seconds =  seconds - (sec_minutes*60)
      time = "#{minutes}:#{seconds}"
      return time
    end  
    end
  end

  class Song
    attr_accessor :title, :artist, :length, :filename
    attr_reader :path
    def initialize(path) 
      @path = path
      self.filename = File.basename(path)
      Mp3Info.open(path) do |mp3|
        self.title, self.artist, self.length = mp3.tag.title, mp3.tag.artist, mp3.length
      end
    end

    def self.filename_to_path(filename); File.join(Ruxtape::MP3_PATH, filename); end

    def time
      minutes = (length/60).to_i; seconds = (((length/60) - minutes) * 60).to_i
      time = "#{minutes}:#{seconds}"
      return time
    end
    
    def update(attrs)
      Mp3Info.open(self.path) do |mp3|
        mp3.tag.title = attrs[:title]
        mp3.tag.artist = attrs[:artist]
      end
    end
  end
end

module Ruxtape::Controllers
  class Index < R '/'
    def get
      if Config.setup? 
        @songs = Mixtape.playlist
        render(:index) 
      else 
        render(:setup)
      end
    end
  end

  class Admin < R '/admin'
    def get
      return redirect('/setup') unless @state.identity
      @songs = Mixtape.playlist
      render :admin
    end
  end

  class Login < R '/login'
    def get
      this_url = 'http:' + URL('/login').to_s
      unless input.finish.to_s == '1'
        begin
          request_state = { }
          oid_request = OpenID::Consumer.new(request_state, nil).begin(input.openid_identifier)
          oid_request.return_to_args['finish'] = '1'
          @state.openid_request = Marshal.dump(request_state)
          redirect(oid_request.redirect_url('http:' + URL('/').to_s, this_url))
        rescue OpenID::DiscoveryFailure
          return 'Couldn\'t find an OpenID at that address, are you sure it is one?'
        end
      else
        request_state = Marshal.restore(@state.openid_request)
        response = OpenID::Consumer.new(request_state, nil).complete(input, this_url)
        @state.delete('openid_request')
        case response.status
        when OpenID::Consumer::SUCCESS
          return redirect R(Setup) unless Config.values[:openid] == response.identity_url.to_s
          @state.identity = response.identity_url.to_s
          return redirect(R(Admin))
        when OpenID::Consumer::FAILURE
          'The OpenID thing doesn\'t think you really are that person, they said: ' + response.message
        else
          raise
        end
      end
    end
  end

  class Restart < R '/admin/restart'
    def post
      return unless signed?
      return redirect('/setup') unless @state.identity
      Config.delete; redirect R(Index)
    end
  end

  class UpdateSong < R '/admin/update_song'
    def post
      return redirect('/setup') unless @state.identity
      path = Song.filename_to_path(input.song_filename)
      @song = Song.new(path)
      @song.update(:artist => input.song_artist, :title => input.song_title)
      redirect R(Admin)
    end
  end

  class Setup < R '/setup'
    def get; Config.setup? ? render(:setup) : redirect(R(Index)); end
    def post
      unless Config.setup?
        Config.setup(:openid => input.openid_address)
        redirect R(Setup)
      else
        redirect R(Index)
      end
    end
  end

  class Upload < R '/admin/upload'
    include FileUtils::Verbose
    def post
      return unless signed?
      return redirect('/setup') unless @state.identity
      @file_attrs = { :filename     => input.file[:filename],
                      :content_type => input.file[:type],
                      :content      => input.file[:tempfile] }
      @path = File.join(Song::Ruxtape::MP3_PATH, @file_attrs[:filename])
      # This works as well, but reads into memory a second time.
#       File.open(@path, 'w') do |file|
#         file << @file_attrs[:content].read
#       end
      cp(@file_attrs[:content].path, @path)
      redirect R(Admin)
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

module Ruxtape::Helpers
  # the following two methods are used to sign url's so XSS attacks are stopped dead
  # it works because XSS attackers can't read the data in our session.
  def sign
    @state.request_signature ||= rand(39_000).to_s(16)
  end
  
  def signed?
    input.signed == @state.request_signature
  end
end


module Ruxtape::Views
  def layout
    xhtml_strict do 
      head do 
        title "Ruxtape => Punks jump up to get beat down."
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/styles.css', :media => 'screen' )
        meta(:content => 'noindex, nofollow', :name => "robots")
        script(:type => 'text/javascript', :src => '/assets/jquery.js')
        script(:type => 'text/javascript', :src => '/assets/ruxtape.js')
        unless @songs.nil?
        end
      end
      body do 
        div.wrapper! do 
          div.header! do 
            div.title! { "Ruxtape, sucka"} 
            div.subtitle! {"#{Ruxtape::Models::Mixtape.song_count} songs, #{Ruxtape::Models::Mixtape.length}"}
          end
          self << yield
          div.footer! do 
            a "Ruxtape 0.1", :href => "http://github.com/ch0wda/ruxtape"
            text "&nbsp;&raquo;&nbsp;"
            a "admin", :href => "/admin"
          end
        end
      end
    end
  end

  def index 
    ul.songs do 
      @songs.each do |song|
        li.song do 
          div.name "#{song.artist} - #{song.title}"
          div.info do 
            div.clock { }
            strong song.time
          end
        end
      end
    end
  end

  def setup
    div.content! do 
      h1 "Get Mixin'"
      if Ruxtape::Models::Config.setup?
        p { text("You're all set and ready to go. Login below") }
        form({ :method => 'get', :action => R(Login, :signed => sign)}) do 
          input :type => "text", :name => "openid_identifier"
          input :type => "submit", :value => "Login OpenID"
        end
      else
        p "Type in your OpenID address below to get started."
        form({ :method => 'post', :action => R(Setup)}) do 
          input :type => "text", :name => "openid_address"
          input :type => "submit", :value => "Save"
        end
      end
    end
  end
  
  def admin
    div.content! do 
      p.login "You are authenticated as #{@state.identity}"
      h1 "Switch Up Your Tape"
      p 'You can upload another song, rearrange your mix, or blow it all away.'
      hr
      h2 "Upload a New Jam"
      form({ :method => 'post', :enctype => "multipart/form-data", 
             :action => R(Upload, :signed => sign)}) do 
        input :type => "file", :name => "file"; br
        input :type => "submit", :value => "Upload"
      end
      hr
      h2 "Edit your songs"
      ul.sorter do 
        @songs.each do |song|
          li.sortable { _song_admin(song) }
        end
      end
      hr
      h2 "Restart"
      p "This will delete all your songs."
      form({ :method => 'post', :action => R(Restart, :signed => sign)}) do 
        input :type => "submit", :value => "Restart"
      end
    end
  end

  def _song_admin(song)
    div.song do 
      div.info do 
        text "#{song.artist} - #{song.title}"
        span.file do 
          "(#{song.filename})"
        end
      end
      div.form do 
        form({ :method => 'post', :action => R(UpdateSong, :signed => sign)}) do 
          input :type => "text", :name => "song_artist", :value => song.artist
          text " - "
          input :type => "text", :name => "song_title", :value => song.title
          input :type => "hidden", :name => "song_filename", :value => song.filename
          input :type => "submit", :value => "Update"
        end
      end
    end
      
  end
end
