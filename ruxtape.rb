$LOAD_PATH << File.join(Dir.getwd, 'lib')

#http://github.com/ahaller/sinatra-openid-consumer-example/blob/master/openid_auth.rb

Dir.glob(File.join(File.dirname(__FILE__),"/vendor/*")).each do |lib|
  $:.unshift File.join(lib, "/lib")
end

require 'rubygems'
require 'sinatra'

require 'configs'
require 'mixtape'
require 'song'
require 'mp3info'
require 'fileutils'
require 'uri'

class Sinatra::Application
  include FileUtils::Verbose
end

enable :sessions

def login_required
  redirect login_url unless logged_in?
end

before do 
  @mixtape = Mixtape.new
end

helpers do 
  def ensure_setup
    if Configs.setup?
    else
      redirect setup_url
    end
  end
  
  def base_url
    base = "http://#{Sinatra::Application.host}"
    port = Sinatra::Application.port == 80 ? base : base << ":#{Sinatra::Application.port}"
  end

  def logged_in?
    !session[:user].nil?
  end

  def url(path='', file=nil)
    [base_url, path, file].join('/')
  end

  def admin_url
    url("admin")
  end

  def login_url
    url("login")
  end

  def setup_url
    url("setup")
  end

  def song_url(song)
    url("songs", song.filename)
  end
end

get '/' do 
  ensure_setup
  erb :index
end

get '/admin' do 
  login_required
  @configs = Configs.attributes
  erb :admin
end

get '/login' do 
  erb :login
end

post '/login/openid' do 
  session[:user] = true
  redirect admin_url
end

get '/logout' do 
  session[:user] = nil
  redirect url
end

get '/setup' do 
  erb :setup
end

post '/setup' do 
  Configs.update_attributes(@params[:configs])
  redirect admin_url
end

post '/admin/songs' do 
  login_required
  song = Song.new(@params[:file][:filename])
  cp(@params[:file][:tempfile].path, song.path)
  song.update(:tracknum => @mixtape.songs.length)
  redirect admin_url
end

put '/admin/songs/:song_name' do 
  login_required
  song = Song.find(@params[:song_name])
  song.update(:artist => @params[:song_artist], :title => @params[:song_title])
  redirect admin_url
end

post '/admin/songs/reorder' do 
  login_required
  songs = @params[:songs].map do |filename| 
    path = File.join(MP3Path, filename)
    Song.find(path) 
  end
  songs.each_with_index { |song, i| song.update :tracknum => i+1 }
  "ok"
end

delete '/admin/songs/:song_name' do 
  login_required
  song = Song.find(@params[:song_name])
  song.delete
  redirect admin_url
end
