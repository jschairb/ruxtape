$LOAD_PATH << File.join(Dir.getwd, 'lib')

require 'rubygems'
require 'sinatra'
require 'mixtape'

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
end

get '/' do 
  erb :index
end

get '/admin' do 
  # params.inspect
  erb :admin
end
