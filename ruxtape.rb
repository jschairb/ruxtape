#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__) + "/vendor"
%w(camping mime/types mp3info yaml openid base64).each { |lib| require lib}

module Camping
  module CookieSessions
    def service(*a)
      if @cookies.identity
        blob, secure_hash = @cookies.identity.to_s.split(':', 2)
        blob = Base64.decode64(blob)
        data = Marshal.restore(blob)
        data = {} unless secure_blob_hasher(blob).strip.downcase == secure_hash.strip.downcase
      else
        blob = ''; data = {}
      end
      
      app = self.class.name.gsub(/^(\w+)::.+$/, '\1')
      @state = (data[app] ||= Camping::H[])
      hash_before = blob.hash
      return super(*a)
    ensure
      data[app] = @state
      blob = Marshal.dump(data)
      unless hash_before == blob.hash
        secure_hash = secure_blob_hasher(blob)
        @cookies.identity = Base64.encode64(blob).gsub("\n", '').strip + ':' + secure_hash
        @headers['Set-Cookie'] = @cookies.map { |k,v| "#{k}=#{C.escape(v)}; path=#{self/"/"}" if v != @k[k] } - [nil]
      end
    end
    
    def secure_blob_hasher(data)
      require 'digest'
      require 'digest/sha2'
      Digest::SHA512::hexdigest(self.class.module_eval('@@state_secret') + data)
    end
  end
end

Camping.goes :Ruxtape

module Ruxtape
  include Camping::CookieSessions
  @@state_secret = "27c9436319ae7c1e760dbd344de08f82b4c7cfcf"
end

module Ruxtape::Models
  class Config
    CONFIG_FILE = File.join(File.expand_path(File.dirname(__FILE__)), 'config', 'config.yml')
    attr_accessor :values
    class << self
      def setup?; return true if File.exist?(CONFIG_FILE) end
      def load; values = YAML.load_file(CONFIG_FILE); end
      def setup(openid)  
        File.open(CONFIG_FILE, "w") { |f| YAML.dump(openid, f) }
      end
    end
  end

  class Song
    MP3_PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs')
    attr_accessor :title, :artist, :length
    def initialize(path) 
      @path = path 
      Mp3Info.open(@path) do |mp3|
        self.title, self.artist, self.length = mp3.tag.title, mp3.tag.artist, mp3.length
      end
    end
    def self.ruxtape
      songs = []
      Dir.glob("#{MP3_PATH}/*.mp3").each { |mp3| songs << Song.new(mp3) }
      return songs
    end

    def self.ruxtape_song_count; Dir.glob("#{MP3_PATH}/*.mp3").length; end
    def self.ruxtape_time; "17 min 22 secs"; end

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
      if Config.setup? 
        @songs = Song.ruxtape 
        render(:index) 
      else 
        render(:setup)
      end
    end
  end

  class Admin < R '/admin'
    def get
      render :admin
    end
  end

  class Login < R '/login'
    def get
      this_url = 'http' + URL('/login').to_s
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
          @state.identity = response.identity_url.to_s
          return redirect(R(HomeScreen))
        when OpenID::Consumer::FAILURE
          'The OpenID thing doesn\'t think you really are that person, they said: ' + response.message
        end
      end
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

  class Upload < R '/upload'
    def post
      file = input.file

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

module Ruxtape::Views
  def layout
    xhtml_strict do 
      head do 
        title "Ruxtape"
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/styles.css', :media => 'screen' )
      end
      body do 
        div.wrapper! do 
          div.header! do 
            div.title! { "Ruxtape, sucka"} 
            div.subtitle! {"#{Ruxtape::Models::Song.ruxtape_song_count} songs, #{Ruxtape::Models::Song.ruxtape_time}"}
          end
          self << yield
          div.footer! do 
            a "Ruxtape 0.1", :href => "http://github.com/ch0wda/ruxtape"
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
        form({ :method => 'get', :action => R(Login)}) do 
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
      h1 "Switch Up Your Tape"
      hr
      h2 "Upload a New Song"
      form({ :method => 'post', :enctype => "multipart/form-data", :action => R(Upload)}) do 
        input :type => "file", :name => "file"; br
        input :type => "submit", :value => "Upload"
      end
      hr
      h2 "Rearrange Your Mixtape Order"
      p "Drag and drop to get the optimal soundz. (Saves automatically.)"
    end
  end
end
