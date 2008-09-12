require 'rubygems'
require 'mosquito'
require File.dirname(__FILE__) + "/../ruxtape"

include Ruxtape::Models

class TestConfig < Camping::ModelTest
end

class TestMixtape < Camping::ModelTest
end

class TestSong < Camping::ModelTest
end

class TestRuxtape < Camping::WebTest

  def standard_gets
    get "/"
    assert_response :success
    assert_match_body %r!Ruxtape!
  end

end
