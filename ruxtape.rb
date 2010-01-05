require 'rubygems'
require 'sinatra'

get '/' do 
  erb :index
end

get '/admin' do 
  # params.inspect
  erb :admin
end


