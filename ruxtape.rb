#!/usr/bin/env ruby
Dir.glob(File.join(File.dirname(__FILE__),"/vendor/*")).each do |lib|
  $:.unshift File.join(lib, "/lib")
end

%w(camping camping/session fileutils yaml base64 uri
   builder mime/types mp3info openid).each { |lib| require lib}

Camping.goes :Ruxtape

module Ruxtape
  include Camping::Session
  MP3_PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs')
  @@state_secret = "27c9436319ae7c1e760dbd344de08f82b4c7cfcf"
  VERSION = "0.1"
end

module Ruxtape::Models
  class Config
    CONFIG_FILE = File.join(File.expand_path(File.dirname(__FILE__)), 'config', 'config.yml')
    class << self
      def delete; File.delete(CONFIG_FILE); Mixtape.delete; end
      def setup?; return true if File.exist?(CONFIG_FILE) end
      def values; YAML.load_file(CONFIG_FILE); end
      def setup(openid)
        File.open(CONFIG_FILE, "w") { |f| YAML.dump({:openid => openid}, f) }
      end
      def write(configs)
        values = self.values
        File.open(CONFIG_FILE, "w") { |f| YAML.dump(values.merge(configs), f) }
      end
      def admin?(ident)
        if setup?
          values[:openid] == ident
        else
          setup(ident)
          true
        end
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
        seconds = "0#{seconds}" if seconds.to_s.size == 1
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
        mp3.tag.tracknum = attrs[:tracknum].to_i if attrs[:tracknum]
      end
    end
    def url_path; "/songs/#{URI.escape(File.basename(path))}"; end

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

  class Admin < R '/admin'
    def get
      return redirect('/setup') unless @state.identity
      @songs = Mixtape.playlist
      @configs = Config.values
      render :admin
    end
  end

  class Login < R '/login'
    def get
      this_url = URL('/login').to_s
      if input.finish.to_s != '1'
        begin
          request_state = { }
          oid_request = OpenID::Consumer.new(request_state, nil).begin(input.openid_identifier)
          oid_request.return_to_args['finish'] = '1'
          @state.openid_request = Marshal.dump(request_state)
          redirect(oid_request.redirect_url(URL('/').to_s, this_url))
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
          return redirect(R(Setup)) unless Config.admin?(identity)
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

  class Logout < R '/logout'
    def get; @state.identity = nil; redirect R(Index); end
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

  class UpdateConfig < R '/admin/update_config'
    def post
      configs = { :openid => input.config_openid, :google => input.config_google }
      Config.write(configs)
      redirect R(Admin)
    end
  end

  class Setup < R '/setup'
    def get; Config.setup? ? render(:setup) : redirect(R(Index)); end
<<<<<<< HEAD:ruxtape.rb
    def post
      unless Config.setup?
        Config.setup(:openid => input.openid_identifier, :google => " ")
        redirect R(Login, :signed => sign)
      else
        redirect R(Index)
      end
    end
=======
>>>>>>> 4d0204c7efa8e6816091f510456a5f39f778a043:ruxtape.rb
  end

  class Upload < R '/admin/upload'
    include FileUtils::Verbose
    def post
      return unless signed?
      return redirect('/setup') unless @state.identity
      @path = File.join(Ruxtape::MP3_PATH, input.file[:filename])
      return redirect(R(Admin)) if @path == Ruxtape::MP3_PATH
      cp(input.file[:tempfile].path, @path)
      Song.new(@path).update(:tracknum => Mixtape.song_count)
      redirect R(Admin)
    end
  end

  class Reorder < R '/admin/reorder'
    def post
      return "invalid request" unless signed?
      if input.songs
        p input.songs
        songs = input.songs.map { |filename| Song.new(File.join(Ruxtape::MP3_PATH, filename)) }
        songs.each_with_index { |song, i| song.update :tracknum => i+1 }
      end
      "ok"
    end
  end

  class Static < R '/(assets|songs)/(.+)'
    MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript', '.swf' => "application/x-shockwave-flash", '.mp3' => 'audio/mpeg'}
    PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public')

    def get(type, path)
      @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
      unless path.include? ".." # prevent directory traversal attacks
        file = "#{PATH}/#{type}/#{path}"
        @headers['X-Sendfile'] = "#{PATH}/#{type}/#{URI.unescape(path)}"
      else
        @status = "403"
        "403 - Invalid path"
      end
    end
  end
end

module Ruxtape::Helpers
  # used to sign url's to stopXSS attacks
  def sign; @state.request_signature ||= rand(39_000).to_s(16); end
  def signed?; input.signed == @state.request_signature; end
end

module Ruxtape::Views
  def layout
    xhtml_strict do
      head do
        title "Ruxtape => Punks jump up to get beat down."
        link(:rel => 'shortcut icon', :href => '/assets/images/favicon.ico')
        
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/styles.css', :media => 'screen' )
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/page-player.css', :media => 'screen' )
        meta(:content => 'noindex, nofollow', :name => "robots")
        %w(jquery.js ui.core.js ui.sortable.js ruxtape.js).each do |lib|
          script(:type => 'text/javascript', :src => "/assets/#{lib}")
        end
      end
      body do
        div.wrapper! do
          div.header! do
            if @state.identity
              div.manage_button do a "Manage", :href => "/admin" end
              div.manage_button do a "Listen", :href => "/" end
            end
            div.title! { "Ruxtape, sucka"}
            div.subtitle! {"#{Ruxtape::Models::Mixtape.song_count} songs / (#{Ruxtape::Models::Mixtape.length})"}
          end
          div.pinstripe do "" end
          self << yield
          div.footer! do 
            a "Ruxtape #{Ruxtape::VERSION}", :href => "http://github.com/ch0wda/ruxtape"
            text "&nbsp;&raquo;&nbsp;"
            @state.identity ? a("Logout", :href => R(Logout)) : a("Login", :href => "/setup")
          end
        end
      end
    end
  end

  def index
    script(:type => 'text/javascript', :src => '/assets/soundmanager/soundmanager2.js')
    # The order of the following js calls is apparently quite critical to proper behaviour.
    script :type  => 'text/javascript' do
      "var PP_CONFIG = {flashVersion: 9,usePeakData: true,useWaveformData: false,useEQData: false,useFavIcon: false}"
    end
    script(:type => 'text/javascript', :src => '/assets/soundmanager/page-player.js')
    script :type  => 'text/javascript' do "soundManager.url = '../../assets/soundmanager';"  end
    div.warning! {"You do not have javascript enabled, this site will not work without it."}
    ul :class  => 'playlist' do 
      @songs.each { |song| li {a("#{song.artist} - #{song.title}", :href=> song.url_path) }}
    end
    _tape_controls
  end

  def setup
    div.content! do
      h1 "Get Mixin'"
      p "Type in your OpenID address below to get started."
      form({ :method => 'get', :action => R(Login, :signed => sign)}) do
        input :type => "text", :name => "openid_identifier"
        input :type => "submit", :value => "Login"
      end
    end
  end

  def admin
    div.content! do 
      p.login { text "You are authenticated as #{@state.identity}." }
      h1 "Switch Up Your Tape"
      p 'You can upload another song, rearrange your mix, or blow it all away.'
      div.admin_area do
        div.admin_left do
          h2 "Upload a New Jam"
          div.graybox do
            form({ :method => 'post', :enctype => "multipart/form-data", 
                   :action => R(Upload, :signed => sign)}) do 
              input :type => "file", :name => "file", :value  => "Browse"
              input :type => "submit", :value => "Upload"
            end
          end
          h2 "Configurations"
          div.graybox do 
            form({ :method => 'post', :action => R(UpdateConfig, :signed => sign)}) do 
              @configs.each do |key, value|
                label "#{key.to_s.capitalize}", :for => "config_#{key}"
                input :type => "text", :name => "config_#{key}", :value => value
              end
              input :type => "submit", :value => "Save"
            end
          end
          div.warning do
            h2 "Restart"
            div.graybox do
              p "This will delete all your songs."
              form({ :method => 'post', :action => R(Restart, :signed => sign)}) do 
#             input :type => "image", :src  => "/assets/images/ruxtape_logo.jpg", :value => "Restart", :name  => "submit"
              input :type => "submit", :value => "Restart", :name  => "submit"
              end
            end
          end
        end
        div.admin_list do
          h2 "Edit Playlist"
          ul.sorter.sorter! do 
            @songs.each do |song|
              li.sortable(:id => "songs_#{song.filename}")  { _song_admin(song) }
            end
          end
          span.signature! sign
        end
      end
    end  
  end

  def _song_admin(song)
    div.song do 
      div.info do 
        h3 "#{song.artist} - #{song.title}"
        div.edit_song_controls do
          span.edit_song_button {"Edit Song"}
          form.delete({ :method => 'post', :action => R(DeleteSong, :signed => sign)}) do 
            input :type => "hidden", :name => "song_filename", :value => song.filename
            input :type => "submit", :value => "Delete"
          end
        end  
      end
      div.edit_song do
        div.edit_song_form do
          h6 "file - (#{song.filename})" 
          form({ :method => 'post', :action => R(UpdateSong, :signed => sign)}) do 
            label 'Artist ', :for => 'song_artist'
            input :type => "text", :name => "song_artist", :value => song.artist
            label 'Song ', :for => 'song_title'
            input :type => "text", :name => "song_title", :value => song.title
            input :type => "hidden", :name => "song_filename", :value => song.filename
            input :type => "submit", :value => "Save"
          end
        end  
      end
    end
  end

  def _tape_controls
    div :id => 'control-template' do
      div.controls { div.statusbar { div.loading ''; div.position ''} }
      div.timing do
        div :id => "sm2_timing", :class => 'timing-data' do 
          span.sm2_position {"%s1"}; span.sm2_total {" / %s2"}
        end
      end
      div.peak { div(:class => 'peak-box') { span :class  => 'l'; span :class  => 'r' }}
    end
    div(:id =>'spectrum-container', :class => 'spectrum-container') do
      div(:class => 'spectrum-box') { div.spectrum {""} }
    end
  end
end
