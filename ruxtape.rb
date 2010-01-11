$LOAD_PATH << File.join(Dir.getwd, 'lib')

Dir.glob(File.join(File.dirname(__FILE__),"/vendor/*")).each do |lib|
  $:.unshift File.join(lib, "/lib")
end

require 'rubygems'
require 'sinatra'
require 'mixtape'
require 'song'
require 'mp3info'
require 'fileutils'
require 'uri'

class Sinatra::Application
  include FileUtils::Verbose
end

before do 
  @mixtape = Mixtape.new
end

helpers do 
  def base_url
    base = "http://#{Sinatra::Application.host}"
    port = Sinatra::Application.port == 80 ? base : base << ":#{Sinatra::Application.port}"
  end

  def url(path='')
    [base_url, path].join('/')
  end

  def admin_url
    [base_url, "admin"].join("/")
  end

  def song_url(song)
    [base_url, "songs", song.filename].join('/')
  end
end

get '/' do 
  erb :index
end

get '/admin' do 
  erb :admin
end

post '/admin/songs' do 
  @path = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs', @params[:file][:filename])
  cp(@params[:file][:tempfile].path, @path)
  Song.new(@path).update(:tracknum => @mixtape.songs.length)
  redirect admin_url
end

delete '/admin/songs/:song_name' do 
  @path = File.join(File.expand_path(File.dirname(__FILE__)), 'public', 'songs', @params[:song_name])
  song = Song.new(@path)
  song.delete
  redirect admin_url
end
