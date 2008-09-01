require 'rubygems'
require 'rack'
require 'ruxtape'

run Rack::Adapter::Camping.new(Ruxtape)