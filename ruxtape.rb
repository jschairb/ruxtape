#!/usr/bin/env ruby

# might need to install id3lib
# on Mac sudo port install id3lib
# sudo env ARCHFLAGS="-arch i386" CONFIGURE_ARGS="--with-opt-dir=/opt/local" gem install id3lib-ruby

$:.unshift File.dirname(__FILE__) + "/lib"
require 'camping'

Camping.goes :Ruxtape

module Ruxtape::Controllers
  class Index < R '/'
    def get
      # grab a list of all files
      render :index
    end
  end

  class Style < R '/styles.css'
    def get
      @headers['Content-Type'] = 'text/css'
      %Q[h1 { background: #800000; color: #FFFAFA;padding: 1em;}
         body {  margin: 0; padding: 0; }]
    end
  end

end

module Ruxtape::Views
  def layout
    html do 
      head do 
        title "Ruxtape"
        style "@import '#{ self / R(Style) }';", :type => 'text/css'
      end
      body do 
        self << yield
      end
    end
  end

  def index 
    h1 "Ruxtape sucka"
  end
end
