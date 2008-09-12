#!/usr/local/bin/ruby -rubygems
require 'camping'

Camping.goes :Bare

module Bare::Controllers
  class Index < R '/'
    def get
      render :index
    end
  end

  # class SendAFile < R '/file'
  #   def get
  #     # Send this file back
  #     
  #   end
  # end

  class ThisOneWillError < R '/error'
    def get
      raise "An error for testing only!"
    end
  end

  class ThisOneWillError404 < R '/error404'
    def get
      @status = 404
    end
  end

  class ThisOneWillRedirect < R '/redirect'
    def get
      redirect R(Page, 'faq')
    end
  end

  class Page < R '/(\w+)'
    def get(page_name)
      render page_name
    end
  end
end

module Bare::Views
  def layout
    html do
      title { 'My Bare' }
      body { self << yield }
    end
  end
  def index
    p 'Hi my name is Charles.'
    p 'Here are some links:'
    ul do
      li { a 'Google', :href => 'http://google.com' }
      li { a 'A sample page', :href => '/sample' }
    end
  end
  def sample
    p 'A sample page'
  end
end

if __FILE__ == $0
  require 'mongrel/camping'

  server = Mongrel::Camping::start("0.0.0.0",3002,"/homepage",Bare)
  puts "** Bare example is running at http://localhost:3002/homepage"
  server.run.join
end
