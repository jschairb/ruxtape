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
