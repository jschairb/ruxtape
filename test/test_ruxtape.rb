require 'rubygems'
$:.unshift File.dirname(__FILE__) + "/../vendor/mosquito/lib"
require 'mosquito'
require File.dirname(__FILE__) + "/../ruxtape"

include Ruxtape::Models

class TestConfig < Camping::ModelTest
  test "should return true" do 
    assert true
  end
end

class TestMixtape < Camping::ModelTest
end

class TestSong < Camping::ModelTest
end

# class TestRuxtape < Camping::WebTest

#   test "should get index" do 
#     get "/"
#     assert_response :success
#     assert_match_body %r!Ruxtape!
#   end

# end
