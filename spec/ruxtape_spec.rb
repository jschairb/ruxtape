require 'ruxtape'
require 'spec'
require 'rack/test'

Spec::Runner.configure do |conf|
  conf.include Rack::Test::Methods
end

set :environment, :test

describe 'Ruxtape' do 

  def app
    Sinatra::Application
  end

  describe "/" do 
    it "renders successfully" do 
      get '/'
      last_response.should be_ok
    end
  end
end
