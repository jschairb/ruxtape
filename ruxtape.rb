#!/usr/bin/env ruby

# might need to install id3lib
# on Mac sudo port install id3lib
# sudo env ARCHFLAGS="-arch i386" CONFIGURE_ARGS="--with-opt-dir=/opt/local" gem install id3lib-ruby

$:.unshift File.dirname(__FILE__) + "/lib"
%w(camping mime/types).each { |lib| require lib}

Camping.goes :Ruxtape

module Ruxtape::Controllers
  class Index < R '/'
    def get
      # grab a list of all files
      false ? render(:setup) : render(:index)
    end
  end

  class Static < R '/assets/(.+)'         
    MIME_TYPES = {'.css' => 'text/css', '.js' => 'text/javascript'}
    PATH = File.join(File.expand_path(File.dirname(__FILE__)), 'public')

    def get(path)
      @headers['Content-Type'] = MIME_TYPES[path[/\.\w+$/, 0]] || "text/plain"
      unless path.include? ".." # prevent directory traversal attacks
        file = "#{PATH}/assets/#{path}"
        @headers['X-Sendfile'] = "#{PATH}/assets/#{path}"
      else
        @status = "403"
        "403 - Invalid path"
      end
    end
  end

end

module Ruxtape::Views
  def layout
    html do 
      head do 
        title "Ruxtape"
        link(:rel => 'stylesheet', :type => 'text/css',
             :href => '/assets/styles.css', :media => 'screen' )
      end
      body do 
        div.wrapper! do 
          div.header! do 
            div.title! { "Ruxtape, sucka"} 
            div.subtitle! {"1 songs, 1 min 47 secs"}
          end
          div.content! do 
            self << yield
          end
        end
      end
    end
  end

  def index 
    ul.songs do 
      li.song do 
        div.name { "The Roots - Live At the T-Connection" }
        div.clock { }
        strong "0:48"
      end
    end
  end

  def setup
    h1 "Get Mixin'"
    p "Create a password for the admin sections."
    p "TODO: a form goes here."
  end
end
