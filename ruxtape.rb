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
  song = Song.new(@params[:file][:filename])
  cp(@params[:file][:tempfile].path, song.path)
  song.update(:tracknum => @mixtape.songs.length)
  redirect admin_url
end

put '/admin/songs/:song_name' do 
  song = Song.find(@params[:song_name])
  song.update(:artist => @params[:song_artist], :title => @params[:song_title])
  redirect admin_url
end

post '/admin/songs/reorder' do 
  songs = @params[:songs].map do |filename| 
    path = File.join(MP3Path, filename)
    Song.find(path) 
  end
  songs.each_with_index { |song, i| song.update :tracknum => i+1 }
  "ok"
end

delete '/admin/songs/:song_name' do 
  song = Song.find(@params[:song_name])
  song.delete
  redirect admin_url
end
