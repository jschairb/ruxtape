require File.dirname(__FILE__) + "/../lib/mosquito"

$KCODE = 'u'
# Sadly, Camping does not mandate UTF-8 - but we will use it here to torment the 
# URL-escaping routines wïs ze ümlåuts.

# We use Sniffer to check if our request is parsed properly. After being called Sniffer
# will raise a Messenger exception with the @input inside.
Camping.goes :Sniffer
class Sniffer::Controllers::ParamPeeker < Sniffer::Controllers::R('/')
  class Messenger < RuntimeError
    attr_reader :packet
    def initialize(packet)
      @packet = packet
    end
  end
  
  def post
    raise Messenger.new(input.dup)
  end
  alias_method :get, :post
end

class Sniffer::Controllers::ServerError
  def get(*a)
    raise a.pop
  end
end
  
class TestMockRequest < Test::Unit::TestCase
  include Mosquito
  
  def setup
    @parsed_input = nil
    @req = MockRequest.new
  end
  
  def test_default_domain_and_port
    assert_equal 'test.host', @req.to_hash['SERVER_NAME']
    assert_equal 'test.host', @req.to_hash['HTTP_HOST']
  end

  def test_envars_translate_to_readers
    %w( server_name path_info accept_encoding user_agent 
    script_name server_protocol cache_control accept_language
    host remote_addr server_software keep_alive referer accept_charset
    version request_uri server_port gateway_interface accept connection 
    request_method).map do | envar  |
      true_value = (@req[envar.upcase] || @req["HTTP_" + envar.upcase])
      assert_not_nil true_value,
        "The environment of the default request should provide #{envar.upcase} or HTTP_#{envar.upcase}"
      assert_nothing_raised do
        assert_equal true_value, @req.send(envar), "The request should understand the reader for #{envar}"
        assert_equal true_value, @req.send(envar.upcase), "The request should understand the reader for #{envar.upcase} " +
          "for backwards compatibility"
      end
    end
  end
  
  def test_accessor_for_query_string
    assert @req.respond_to?(:query_string), "The request must have a reader for query string"
    assert @req.respond_to?(:query_string=), "The request must have a writer for query string"
    
    qs = "one=two&foo=bar"
    assert_nothing_raised { @req.query_string = qs }
    assert_equal "?one=two&foo=bar", @req.query_string,
      "The request should return the query string segment with a question mark"
    
    qs = "?one=two&foo=bar"
    assert_equal "?one=two&foo=bar", @req.query_string, 
      "The request should return the query string segment with one and only one question mark"
    
    assert_equal '/?one=two&foo=bar', @req['REQUEST_URI'],
      "The assigned query string should be propargated to REQUEST_URI"

    assert_equal 'one=two&foo=bar', @req['QUERY_STRING'],
      "The assigned query string should be propargated to QUERY_STRING"
    
    @req.query_string = ''
    assert_equal '/', @req['REQUEST_URI'], "The query part should be removed from the REQUEST_URI along with the qmark"
  end
  
  def test_query_string_composition_from_params
    composable_hash = {
      :foo => "bar",
      :user => {
        :login => "boss",
        :password => "secret",
        :friend_ids => [1, 2, 3]
      }
    }
    
    assert @req.respond_to?(:query_string_params=)
    @req.query_string_params = composable_hash
    
    ref = '?foo=bar&user[friend_ids]=1&user[friend_ids]=2&user[friend_ids]=3&user[login]=boss&user[password]=secret'
    assert_equal normalize_qs(ref), normalize_qs(@req.query_string)
    assert_equal "/"+ref, @req['REQUEST_URI'], "The query string parameters should be propagated to the " + 
      "request uri and be in their sorted form"
    assert_equal normalize_qs(ref), normalize_qs(@req["QUERY_STRING"]), "The query string should also land in QUERY_STRING"
  end
  
  def test_qs_assignment_with_empty_hash_unsets_envar
    @req.query_string_params = {}
    assert_equal '', @req.query_string, "When an empty hash is assigned the query string should be empty"
    assert_nil @req.to_hash['QUERY_STRING'], "The key for QUERY_STRING should be unset in the environment"
  end
  
  def test_multipart_boundary_generation
    boundaries = (1..40).map do
      @req.generate_boundary
    end
    assert_equal boundaries.uniq.length, boundaries.length, "All boundaries generated should be unique"
    assert_equal boundaries, boundaries.grep(/^msqto\-/), "All boundaries should be prepended with msqto-"
  end
  
  def test_method_missing_is_indeed_missing
    assert_raise(NoMethodError) { @req.kaboodle! }
  end
  
  def test_extract_values
    t = {
          :foo => "bar",
          :bar => {
            :baz => [1,2,3],
            :bam => "trunk",
          },
          :sequence => "xyz"
    }
    assert_equal ["bar", "1", "2" , "3", "trunk", "xyz"].sort, @req.send(:extract_values, t).map(&:to_s).sort,
      "should properly extract infinitely deeply nested values"
  end
  
  def test_post_composition_with_urlencoding
    assert_equal 'GET', @req['REQUEST_METHOD'], "The default request method is GET"

    @req.post_params = {:hello => "welæcome", :name => "john", :data => {:values => [1,2,3] } }
    assert_kind_of StringIO, @req.body, "The request body is an IO"
    assert_equal 'POST', @req['REQUEST_METHOD'], 
      "When the parameters are assigned the request should be switched to POST"
    assert_equal "application/x-www-form-urlencoded", @req['CONTENT_TYPE'], 
      "The content-type should be switched accordingly"
    assert_equal normalize_qs('data[values]=1&data[values]=2&data[values]=3&hello=wel%C3%A6come&name=john'), normalize_qs(@req.body.read),
      "The body should now contain URL-encoded form parameters"
  end
  
  def test_post_composition_accepts_verbatim_strings_as_payload
    assert_equal 'GET', @req['REQUEST_METHOD'], "The default request method is GET"
    @req.post_params = 'foo=bar&baz=bad'
    assert_equal 'POST', @req['REQUEST_METHOD']
    assert_equal "application/x-www-form-urlencoded", @req['CONTENT_TYPE'], 
      "The content-type should be switched accordingly"
    assert_equal 'foo=bar&baz=bad', @req.body.read, "The payload should have been assigned directly"
  end
  
  def test_append_to_query_string
    @req.append_to_query_string "x=y&boo=2"
    @req.append_to_query_string "zaz=taing&schmoo=tweed"
    assert_equal "x=y&boo=2&zaz=taing&schmoo=tweed", @req["QUERY_STRING"]
  end
  
  # We could let that one slip but why? If someone does TDD he deserves gratification
  def test_post_composition_requiring_multipart_with_arrays_warns_the_noble_developer_and_everyone_stays_happy
    assert_raise(Mosquito::SageAdvice) do
      @req.post_params = {:hello => "welcome", :name => "john", :arrayed => [1, 2, 3], :somefile => MockUpload.new("pic.jpg") }
    end
    
    assert_nothing_raised do
      @req.post_params = {:hello => "welcome", :name => "john", :arrayed => [1, 2, 3], :not_a_file => "shtaink" }
    end
  end

  # We could let that one slip but why? If someone does TDD he deserves gratification
  def test_get_composition_with_files_warns_the_noble_developer_and_he_quickly_corrects_himself
    assert_raise(Mosquito::SageAdvice) do
      @req.query_string_params = {:hello => "welcome", :somefile => MockUpload.new("pic.jpg") }
    end
  end
  
  def test_post_composition_from_values_requiring_multipart
    assert_equal 'GET', @req['REQUEST_METHOD'], "The default request method is GET"
    
    @req.post_params = {:hello => "welcome", :name => "john", :somefile => MockUpload.new("pic.jpg") }
    
    assert_kind_of StringIO, @req.body, "The request body is an IO"
    assert_equal 'POST', @req['REQUEST_METHOD'], "When the parameters are assigned the request should be switched to POST"
    ctype, boundary = @req['CONTENT_TYPE'].split(/=/)
    boundary_with_prefix = "--" + boundary
    assert_equal "multipart/form-data; boundary", ctype, "The content-type should be switched accordingly"
    
    @req.body.rewind
    output = @req.body.read.split("\r")
    ref_segments = [
      "--#{boundary}", 
      "\nContent-Disposition: form-data; name=\"hello\"", 
      "\n", "\nwelcome", "\n--#{boundary}",
      "\nContent-Disposition: form-data; name=\"name\"",
      "\n",
      "\njohn",
      "\n--#{boundary}",
      "\nContent-Disposition: form-data; name=\"somefile\"; filename=\"pic.jpg\"",
      "\nContent-Type: image/jpeg", "\nContent-Length: 120",
      "\n",
      /\nStub file pic\.jpg \n([AZ-az]{120})\n/,
      "\n--#{boundary}--"
    ]

    ref_segments.each_with_index do | ref, idx |
      if ref == String
        assert_equal ref, output[idx], "The segment #{idx} should be #{ref}"
      elsif ref == Regexp
        assert_match ref, output[idx], "The segment #{idx} should match #{ref}"
      end
    end    
  end
  
  private
    # Remove the question mark, sort the pairs
    def normalize_qs(query_string)
      "?" + query_string.to_s.gsub(/^\?/, '').split(/&/).sort.join('&')
    end
end


class TestMockRequestWithRoundtrip < Test::Unit::TestCase
  include Mosquito
  def setup
    @parsed_input = nil
    @req = MockRequest.new
  end

  def test_multipart_post_properly_roundtripped
    @req.post_params = {:hello => "welcome", :name => "john", :somefile => MockUpload.new("pic.jpg") }
    
    run_request!
    
    # Reference is something like this
    # {"name"=>"john", "somefile"=>{"name"=>"somefile", "type"=>"image/jpeg",
    # "tempfile"=>#<File:/tmp/C.9366.0>, "filename"=>"pic.jpg"}, "hello"=>"welcome"}

    assert_equal "john", @parsed_input["name"]
    assert_kind_of Hash, @parsed_input["somefile"]
    assert_equal "somefile", @parsed_input["somefile"]["name"]
    assert_equal "pic.jpg", @parsed_input["somefile"]["filename"]
    assert_equal "image/jpeg", @parsed_input["somefile"]["type"]
    assert_kind_of Tempfile, @parsed_input["somefile"]["tempfile"]
    
    
    @req.post_params = {:hello => "welcome", :name => "john", :arrayed => [1, 2, 3], :somefile => "instead" }
    assert_kind_of StringIO, @req.body, "The request body is an IO"
    assert_match /urlencoded/, @req['CONTENT_TYPE'], "The ctype should have been switched back to urlencoded"
    
    run_request!
    
    ref = {"name"=>"john", "arrayed"=>["1", "2", "3"], "somefile"=>"instead", "hello"=>"welcome"}
    assert_equal ref, @parsed_input, "Camping should have parsed our params just like so"
  end
  
  def test_reader_and_writer_for_domain
    assert_nothing_raised { assert_equal 'test.host', @req.domain }
    assert_nothing_raised { @req.domain = "foo.dzing" }
    
    assert_equal 'foo.dzing', @req.domain 
    assert_equal 'foo.dzing', @req['SERVER_NAME'] 
    assert_equal 'foo.dzing', @req['HTTP_HOST'] 
  end
  
  def test_query_string_properly_roundtripped
    parsed = {"user"=> {"friend_äidéis"=>["1", "2", "3"], "paßwort"=>"secret", "login"=>"boss"}, "foo"=>"bar"}
    @req.query_string_params = parsed
    run_request!
    assert_equal parsed, @parsed_input
  end
  
  def test_urlencoded_post_properly_roundtripped
    assert_equal 'GET', @req['REQUEST_METHOD'], "The default request method is GET"
    
    @req.post_params = {:hello => "welæcome", :name => "john", :data => {:values => [1,2,3] } }
    run_request!
    ref = {"name"=>"john", "hello"=>"welæcome", "data"=>{"values"=>["1", "2", "3"]}}
    assert_equal ref, @parsed_input, "Camping should have parsed our input like so"
  end
  private
    def run_request!
      @req.body.rewind
      begin
        Sniffer.run(@req.body, @req.to_hash)
      rescue Sniffer::Controllers::ParamPeeker::Messenger => e
        @parsed_input = e.packet
      end
    end
end