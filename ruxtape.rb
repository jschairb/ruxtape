#!/usr/bin/env ruby
Dir.glob(File.join(File.dirname(__FILE__),"/vendor/*")).each do |lib|
  $:.unshift File.join(lib, "/lib")
end

%w(camping fileutils yaml base64 
   builder mime/types mp3info openid).each { |lib| require lib}

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
        Dir.glob("#{Ruxtape::MP3_PATH}/*.mp3") { |mp3| songs << Song.new(mp3) }
        songs.sort
      end
      def song_count; Dir.glob("#{Ruxtape::MP3_PATH}/*.mp3").length; end
      def length 
        minutes, seconds = 0,0
        self.playlist.each { |song| time = song.time.split(':'); minutes += time[0].to_i; seconds += time[1].to_i }
        sec_minutes = (seconds/60).to_i
        minutes += sec_minutes; seconds =  seconds - (sec_minutes*60)
        "#{minutes}:#{seconds}"
      end
    end
  end

  class Song
    attr_accessor :title, :artist, :length, :filename, :tracknum
    attr_reader :path
    def initialize(path) 
      @path = path
      self.filename = File.basename(path)
      Mp3Info.open(path) do |mp3|
        self.title, self.artist, self.length, self.tracknum = mp3.tag.title, mp3.tag.artist, mp3.length, mp3.tag.tracknum
      end
    end

    def self.filename_to_path(filename); File.join(Ruxtape::MP3_PATH, filename); end

    def delete; File.delete(self.path); end

    def time
      minutes = (length/60).to_i; seconds = (((length/60) - minutes) * 60).to_i
      "#{minutes}:#{seconds}"
    end
    
    def update(attrs)
      Mp3Info.open(self.path) do |mp3|
        mp3.tag.title = attrs[:title] if attrs[:title]
        mp3.tag.artist = attrs[:artist] if attrs[:artist]
        mp3.tag.tracknum = attrs[:tracknum] if attrs[:tracknum]
      end
    end

    def <=>(other)
      self.tracknum <=> other.tracknum
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

  class Playlist < R '/xspf.xml'
    def get
      @headers['Content-Type'] = 'application/xml'
      "#{Mixtape.to_xml}"
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
          identity = response.identity_url.to_s.sub(/^http:\/\//, '').sub(/\/$/,'')
          return redirect(R(Setup)) unless Config.values[:openid] == identity
          @state.identity = identity
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

  class DeleteSong < R '/admin/delete_song'
    def post
      return redirect('/setup') unless @state.identity
      path = Song.filename_to_path(input.song_filename)
      @song = Song.new(path)
      @song.delete
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
      @path = File.join(Song::Ruxtape::MP3_PATH, input.file[:filename])
      cp(input.file[:tempfile].path, @path)
      Song.new(@path).update(:tracknum => Mixtape.song_count)
      redirect R(Admin)
    end
  end

  class Static < R '/(assets|songs)/(.+)'
    MIME_TYPES = {'.css' => 'text/css',
                  '.js' => 'text/javascript', 
                  '.swf' => "application/x-shockwave-flash",
                  '.mp3' => 'audio/mpeg'}
    PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public')

    def get(type, path)
      @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
      unless path.include? ".." # prevent directory traversal attacks
        file = "#{PATH}/#{type}/#{path}"
        @headers['X-Sendfile'] = "#{PATH}/#{type}/#{path}"
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
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/page-player.css', :media => 'screen' )             
        meta(:content => 'noindex, nofollow', :name => "robots")
        script(:type => 'text/javascript', :src => '/assets/jquery.js')
        script(:type => 'text/javascript', :src => '/assets/soundmanager/soundmanager2.js')
        script(:type => 'text/javascript', :src => '/assets/ruxtape.js')
# The order of the following js calls is apparently quite critical to proper behaviour.
        script :type  => 'text/javascript' do "
          var PP_CONFIG = {
            flashVersion: 9,
            usePeakData: true,
            useWaveformData: false,
            useEQData: false,
            useFavIcon: false
            }
          " end
        script(:type => 'text/javascript', :src => '/assets/soundmanager/page-player.js')
        script :type  => 'text/javascript' do "soundManager.url = '../../assets/soundmanager';"  end          
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
          #This Gets Dynamically copied 
          #after each link for the fancy controls       

                div :id => 'control-template' do
                  div.controls do
                    div.statusbar do
                      div.loading do "" end 
                      div.position do "" end
                    end
                  end
                  div.timing do
                    div :id => "sm2_timing", :class => 'timing-data' do 
                      span.sm2_position do "%s1" end
                      span.sm2_total do " / %s2" end
                    end
                  end
                  div.peak do
                      div :class => 'peak-box' do
                        span :class  => 'l' do {} end
                        span :class  => 'r' do {} end
                      end
                    end   
                  end
                  div :id =>'spectrum-container', :class => 'spectrum-container' do
                    div :class => 'spectrum-box' do
                      div.spectrum do "" end
                    end
                  end
        end
      end
    end
  end
  

  def index 
    div.warning! {"You do not have javascript enabled, this site will not work without it."}
    ul :class  => 'playlist' do 
      @songs.each do |song|
        li do 
          a :href=>"/songs/#{CGI.escape(File.basename(song.path))}" do "#{song.artist} - #{song.title}" end
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
      p.login { 
        text "You are authenticated as #{@state.identity}. View your "
        a "Ruxtape", :href => "/"; text "."
      }
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

        form.delete({ :method => 'post', :action => R(DeleteSong, :signed => sign)}) do 
          input :type => "hidden", :name => "song_filename", :value => song.filename
          input :type => "submit", :value => "Delete"
        end
      end
    end
      
  end
end
