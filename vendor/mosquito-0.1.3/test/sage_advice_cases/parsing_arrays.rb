require 'rubygems'
require 'camping'

Camping.goes :ParsingArrays

class ParsingArrays::Controllers::Klonk < ParsingArrays::Controllers::R('/')
  def get; render :foam; end
  def post;  input.inspect; end
end

module ParsingArrays::Views
  def foam
    h2 "This is multipart with arrays"
    form(:method => :post, :enctype => 'multipart/form-data') { _inputs }
    h2 "This is urlencoded with arrays"
    form(:method => :post, :enctype => 'application/x-www-form-urlencoded') { _inputs }
  end
  
  def _inputs
    input :type => :text, :name => "array", :value => '1'
    input :type => :text, :name => "array", :value => '2'
    input :type => :text, :name => "array", :value => '3'
    input :type => :submit, :name => 'flush', :value => 'Observe'
  end
end