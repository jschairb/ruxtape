%w(
rubygems
test/unit
active_record
active_record/fixtures
camping
camping/session
fileutils
tempfile
stringio
).each { |lib| require lib }

module Mosquito
  VERSION = '0.1.3'
  
  # For various methods that need to generate random text
  def self.garbage(amount) #:nodoc:
    fills = ("a".."z").to_a
    str = (0...amount).map do
      v = fills[rand(fills.length)]
      (rand(2).zero? ? v.upcase : v)
    end
    str.join
  end

  # Will be raised if you try to test for something Camping does not support.
  # Kind of a safeguard in the deep ocean of metaified Ruby goodness.
  class SageAdvice < RuntimeError; end

  # Will be raised if you try to call an absolute, canonical URL (with scheme and server).
  # and the server does not match the specified request.
  class NonLocalRequest < RuntimeError; end
  
  def self.stash(something) #:nodoc:
    @stashed = something
  end

  def self.unstash #:nodoc:
    x, @stashed = @stashed, nil; x
  end
end

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ":memory:")
ActiveRecord::Base.logger = Logger.new("test/test.log") rescue Logger.new("test.log")

# This needs to be set relative to the file where the test comes from, NOT relative to the
# mosquito itself
Test::Unit::TestCase.fixture_path = "test/fixtures/"

class Test::Unit::TestCase #:nodoc:
  def create_fixtures(*table_names)
    if block_given?
      self.class.fixtures(*table_names) { |*anything| yield(*anything) }
    else
      self.class.fixtures(*table_names)
    end
  end
  
  def self.fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
    end
  end

  ##
  # From Jay Fields.
  #
  # Allows tests to be specified as a block.
  #
  #   test "should do this and that" do
  #     ...
  #   end
  
  def self.test(name, &block)
    test_name = :"test_#{name.gsub(' ','_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name.to_s
    define_method test_name, &block
  end

  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  self.use_transactional_fixtures = true
  # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  self.use_instantiated_fixtures  = false
end

# Mock request is used for composing the request body and headers
class Mosquito::MockRequest
  # Should be a StringIO. However, you got some assignment methods that will
  # stuff it with encoded parameters for you
  attr_accessor :body
  
  DEFAULT_HEADERS = {
    'SERVER_NAME' => 'test.host',
    'PATH_INFO' => '',
    'HTTP_ACCEPT_ENCODING' => 'gzip,deflate',
    'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.8.0.1) Gecko/20060214 Camino/1.0',
    'SCRIPT_NAME' => '/',
    'SERVER_PROTOCOL' => 'HTTP/1.1',
    'HTTP_CACHE_CONTROL' => 'max-age=0',
    'HTTP_ACCEPT_LANGUAGE' => 'en,ja;q=0.9,fr;q=0.9,de;q=0.8,es;q=0.7,it;q=0.7,nl;q=0.6,sv;q=0.5,nb;q=0.5,da;q=0.4,fi;q=0.3,pt;q=0.3,zh-Hans;q=0.2,zh-Hant;q=0.1,ko;q=0.1',
    'HTTP_HOST' => 'test.host',
    'REMOTE_ADDR' => '127.0.0.1',
    'SERVER_SOFTWARE' => 'Mongrel 0.3.12.4',
    'HTTP_KEEP_ALIVE' => '300',
    'HTTP_REFERER' => 'http://localhost/',
    'HTTP_ACCEPT_CHARSET' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
    'HTTP_VERSION' => 'HTTP/1.1',
    'REQUEST_URI' => '/',
    'SERVER_PORT' => '80',
    'GATEWAY_INTERFACE' => 'CGI/1.2',
    'HTTP_ACCEPT' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
    'HTTP_CONNECTION' => 'keep-alive',
    'REQUEST_METHOD' => 'GET',
  }

  def initialize
    @headers = DEFAULT_HEADERS.with_indifferent_access # :-)
    @body = StringIO.new('hello Camping')
  end
  
  # Returns the hash of headers  
  def to_hash
    @headers
  end

  # Gets a header  
  def [](key)
    @headers[key]
  end
  
  # Sets a header
  def []=(key, value)
    @headers[key] = value
  end
  alias_method :set, :[]=
  
  # Retrieve a composed query string (including the eventual "?") with URL-escaped segments
  def query_string
    (@query_string_with_qmark.blank? ? '' : @query_string_with_qmark)
  end

  # Set a composed query string, should have URL-escaped segments and include the elements after the "?"
  def query_string=(nqs)
    @query_string_with_qmark = nqs.gsub(/^([^\?])/, '?\1')
    @headers["REQUEST_URI"] = @headers["REQUEST_URI"].split(/\?/).shift + @query_string_with_qmark
    if nqs.blank?
      @headers.delete "QUERY_STRING"
    else
      @headers["QUERY_STRING"] = nqs.gsub(/^\?/, '')
    end
  end
  
  # Retrieve the domain (analogous to HTTP_HOST)
  def domain
    server_name || http_host
  end
  
  # Set the domain (changes both HTTP_HOST and SERVER_NAME)
  def domain=(nd)
    self['SERVER_NAME'] = self['HTTP_HOST'] = nd
  end
  
  # Allow getters like this:
  #  o.REQUEST_METHOD or o.request_method
  def method_missing(method_name, *args)
    triables = [method_name.to_s, method_name.to_s.upcase, "HTTP_" + method_name.to_s.upcase]
    triables.map do | possible_key |
      return @headers[possible_key] if @headers.has_key?(possible_key)
    end
    super(method_name, args)
  end
  
  # Assign a hash of parameters that should be used for the query string
  def query_string_params=(new_param_hash)
    self.query_string = qs_build(new_param_hash)
  end

  # Append a freeform segment to the query string in the request. Useful when you
  # want to quickly combine the query strings.
  def append_to_query_string(piece)
    new_qs = '?' + [self.query_string.gsub(/^\?/, ''), piece].reject{|e| e.blank? }.join('&')
    self.query_string = new_qs
  end
  
  # Assign a hash of parameters that should be used for POST. These might include
  # objects that act like a file upload (with #original_filename and all)
  def post_params=(new_param_hash_or_str)
    # First see if this is a body payload
    if !new_param_hash_or_str.kind_of?(Hash)
      compose_verbatim_payload(new_param_hash_or_str)
    # then check if anything in the new param hash resembles an uplaod
    elsif extract_values(new_param_hash_or_str).any?{|value| value.respond_to?(:original_filename) }
      compose_multipart_params(new_param_hash_or_str)
    else
      compose_urlencoded_params(new_param_hash_or_str)
    end
  end
  
  # Generates a random 22-character MIME boundary (useful for composing multipart POSTs)
  def generate_boundary
     "msqto-" + Mosquito::garbage(16)
  end
  
  private
    # Quickly URL-escape something
    def esc(t); Camping.escape(t.to_s);end
  
    # Extracts an array of values from a deeply-nested hash
    def extract_values(hash_or_a)
      returning([]) do | vals |
        flatten_hash(hash_or_a) do | keys, value |
          vals << value
        end
      end
    end
    
    # Configures the test request for a POST
    def compose_urlencoded_params(new_param_hash)
      self['REQUEST_METHOD'] = 'POST'
      self['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
      @body = StringIO.new(qs_build(new_param_hash))
    end
    
    def compose_verbatim_payload(payload)
      self['REQUEST_METHOD'] = 'POST'
      self['CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
      @body = StringIO.new(payload)
    end
    
    # Configures the test request for a multipart POST
    def compose_multipart_params(new_param_hash)
      # here we check if the encoded segments contain the boundary and should generate a new one
      # if something is matched
      boundary = "----------#{generate_boundary}"
      self['REQUEST_METHOD'] = 'POST'
      self['CONTENT_TYPE'] = "multipart/form-data; boundary=#{boundary}"
      @body = StringIO.new(multipart_build(new_param_hash, boundary))
    end
    
    # Return a multipart value segment from a file upload handle.
    def uploaded_file_segment(key, upload_io, boundary)
      <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"; filename="#{Camping.escape(upload_io.original_filename)}"\r
Content-Type: #{upload_io.content_type}\r
Content-Length: #{upload_io.size}\r
\r
#{upload_io.read}\r
EOF
    end
    
    # Return a conventional value segment from a parameter value
    def conventional_segment(key, value, boundary)
      <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"\r
\r
#{value}\r
EOF
    end
    
    # Build a multipart request body that includes both uploaded files and conventional parameters.
    # To have predictable results we sort the output segments (a hash passed in will not be
    # iterated over in the original definition order anyway, as a good developer should know)
    def multipart_build(params, boundary)
      flat = []
      flatten_hash(params) do | keys, value |
        if keys[-1].nil? # warn the user that Camping will never see that
          raise Mosquito::SageAdvice, 
            "Camping will only show you the last element of the array when using multipart forms"
        end
        
        flat_key = [esc(keys.shift), keys.map{|k| "[%s]" % esc(k) }].flatten.join
        if value.respond_to?(:original_filename)
          flat << uploaded_file_segment(flat_key, value, boundary)
        else
          flat << conventional_segment(flat_key, value, boundary)
        end
      end
      flat.sort.join("")+"--#{boundary}--\r"
    end
    
    # Build a query string. The brackets are NOT encoded. Camping is peculiar in that
    # in contrast to Rails it wants item=1&item=2 to make { item=>[1,2] } to make arrays. We have
    # to account for that.
    def qs_build (hash)
      returning([]) do | qs |
        flatten_hash(hash) do | keys, value |
          keys.pop if keys[-1].nil? # cater for camping array handling
          if value.respond_to?(:original_filename)
            raise Mosquito::SageAdvice, "Sending a file using GET won't do you any good"
          end
          
          qs << [esc(keys.shift), keys.map{|k| "[%s]" % esc(k)}, '=', esc(value)].flatten.join
        end
      end.sort.join('&')
    end
    
    # Will accept a hash or array of any depth, collapse it into 
    # pairs in the form of ([first_level_k, second_level_k, ...], value)
    # and yield these pairs as it goes to the supplied block. Some
    # pairs might be yieled twice because arrays create repeating keys.
    def flatten_hash(hash_or_a, parent_keys = [], &blk)
      if hash_or_a.is_a?(Hash)
        hash_or_a.each_pair do | k, v |
          flatten_hash(v, parent_keys + [k], &blk)
        end
      elsif hash_or_a.is_a?(Array)
        hash_or_a.map do | v |
          blk.call(parent_keys + [nil], v)
        end
      else
        blk.call(parent_keys, hash_or_a)
      end
    end
end

# Works like a wrapper for a simulated file upload. To use:
#
#   uploaded = Mosquito::MockUpload.new("beach.jpg")
#
# This will create a file with the JPEG content-type and 122 bytes of purely random data, which
# can then be submitted as a part of the test request
class Mosquito::MockUpload < StringIO
  attr_reader :local_path, :original_filename, :content_type, :extension
  IMAGE_TYPES = {:jpg => 'image/jpeg', :png => 'image/png', :gif => 'image/gif',
    :pdf => 'application/pdf' }.stringify_keys
  
  def initialize(filename)
    tempname = "tempfile_#{Time.now.to_i}"
    
    @temp = ::Tempfile.new(tempname)
    @local_path = @temp.path    
    @original_filename = File.basename(filename)
    @extension = File.extname(@original_filename).gsub(/^\./, '').downcase
    @content_type = IMAGE_TYPES[@extension] || "application/#{@extension}"
    
    size = 100.bytes
    super("Stub file %s \n%s\n" % [@original_filename, Mosquito::garbage(size)])
  end
  
  def inspect
    info = " @size='#{length}' @filename='#{original_filename}' @content_type='#{content_type}'>"
    super[0..-2] + info
  end

end

# Stealing our assigns the evil way. This should pose no problem
# for things that happen in the controller actions, but might be tricky
# if some other service upstream munges the variables.
# This service will always get included last (innermost), so it runs regardless of
# the services upstream (such  as HTTP auth) that might not call super 
module Mosquito::Proboscis #:nodoc:
  def service(*a)
    returning(super(*a)) do
      a = instance_variables.inject({}) do | assigns, ivar |
        assigns[ivar.gsub(/^@/, '')] = instance_variable_get(ivar); assigns
      end
      Mosquito.stash(::Camping::H[a])
    end
  end
end

module Camping

  class Test < Test::Unit::TestCase

    def test_dummy; end #:nodoc

    # The reverse of the reverse of the reverse of assert(condition)
    def deny(condition, message='')
      assert !condition, message
    end

    # http://project.ioni.st/post/217#post-217
    #
    #  def test_new_publication
    #    assert_difference(Publication, :count) do
    #      post :create, :publication_title => ...
    #      # ...
    #    end
    #  end
    #
    # Is the number of items different?
    #
    # Can be used for increment and decrement.
    #
    def assert_difference(object, method = :count, difference = 1)
      initial_value = object.send(method)
      yield
      assert_equal initial_value + difference, object.send(method), "#{object}##{method}"
    end
    
    # See +assert_difference+
    def assert_no_difference(object, method, &block)
      assert_difference object, method, 0, &block
    end
  end
  
  # Used to test the controllers and rendering. The test should be called <App>Test
  # (BlogTest for the aplication called Blog). A number of helper instance variables
  # will be created for you - @request, which will contain a Mosquito::MockRequest
  # object, @response (contains the response with headers and body), @cookies (a hash)
  # and @state (a hash). Request and response will be reset in each test.
  class WebTest < Test
    
    # Gives you access to the instance variables assigned by the controller 
    attr_reader :assigns
    
    def test_dummy; end #:nodoc
    
    def setup
      @class_name_abbr = self.class.name.gsub(/^Test/, '')
      @request = Mosquito::MockRequest.new
      @cookies, @response, @assigns = {}, {}, {}
    end
    
    # Send a GET request to a URL
    def get(url='/', vars={})
      send_request url, vars, 'GET'
    end

    # Send a POST request to a URL. All requests except GET will allow
    # setting verbatim URL-encoded parameters as the third argument instead
    # of a hash.
    def post(url, post_vars={})
      send_request url, post_vars, 'POST'
    end

    # Send a DELETE request to a URL. All requests except GET will allow
    # setting verbatim URL-encoded parameters as the third argument instead
    # of a hash.
    def delete(url, vars={})
      send_request url, vars, 'DELETE'
    end

    # Send a PUT request to a URL. All requests except GET will allow
    # setting verbatim URL-encoded parameters as the third argument instead
    # of a hash.
    def put(url, vars={})
      send_request url, vars, 'PUT'
    end

    # Send any request. We will try to guess what you meant - if there are uploads to be
    # processed it's not going to be a GET, that's for sure.
    def send_request(url, post_vars, method)
      
      if method.to_s.downcase == "get"
        @request.query_string_params = post_vars
      else
        @request.post_params = post_vars
      end
      
      # If there is some stuff in the URL to be used as a query string, why ignore it?
      url, qs_from_url = url.split(/\?/)
      
      relativize_url!(url)
      
      @request.append_to_query_string(qs_from_url) if qs_from_url
      
      # We do allow the user to override that one
      @request['REQUEST_METHOD'] = method
      
      @request['SCRIPT_NAME'] = '/' + @class_name_abbr.downcase
      @request['PATH_INFO'] = '/' + url
      
      @request['REQUEST_URI'] = [@request.SCRIPT_NAME, @request.PATH_INFO].join('').squeeze('/')
      unless @request['QUERY_STRING'].blank?
        @request['REQUEST_URI'] += ('?' + @request['QUERY_STRING']) 
      end
      
      if @cookies
        @request['HTTP_COOKIE'] = @cookies.map {|k,v| "#{k}=#{Camping.escape(v)}" }.join('; ')
      end
      
      # Inject the proboscis if we haven't already done so
      pr = Mosquito::Proboscis
      eval("#{@class_name_abbr}.send(:include, pr) unless #{@class_name_abbr}.ancestors.include?(pr)")
      
      # Run the request
      @response = eval("#{@class_name_abbr}.run @request.body, @request")
      @assigns = Mosquito::unstash
      
      # We need to restore the cookies separately so that the app
      # restores our session on the next request. We retrieve cookies and
      # the session in their assigned form instead of parsing the headers and
      # doing a deserialization cycle 
      @cookies = @assigns[:cookies] || H[{}]
      @state = @assigns[:state] || H[{}]
      
      if @response.headers['X-Sendfile']
        @response.body = File.read(@response.headers['X-Sendfile'])
      end
    end
    
    # Assert a specific response (:success, :error or a freeform error code as integer)
    def assert_response(status_code)
      case status_code
      when :success
        assert_equal 200, @response.status
      when :redirect
        assert_equal 302, @response.status
      when :error
        assert @response.status >= 500, 
          "Response status should have been >= 500 but was #{@response.status}"
      else
        assert_equal status_code, @response.status
      end
    end
    
    # Check that the text in the body matches a regexp
    def assert_match_body(regex, message=nil)
      assert_match regex, @response.body, message
    end
    
    # Opposite of +assert_match_body+
    def assert_no_match_body(regex, message=nil)
      assert_no_match regex, @response.body, message
    end
    
    # Make sure that we are redirected to a certain URL. It's not needed
    # to prepend the URL with a mount (instead of "/blog/latest-news" you can use "/latest-news")
    #
    # Checks both the response status and the url.
    def assert_redirected_to(url, message=nil)
      assert_response :redirect
      assert_equal url, extract_redirection_url, message
    end
    
    # Assert that a cookie of name matches a certain pattern
    def assert_cookie(name, pat, message=nil)
      assert_match pat, @cookies[name], message
    end
    
    # Nothing is new under the sun
    def follow_redirect
      get extract_redirection_url
    end
    
    # Quickly gives you a handle to a file with random content
    def upload(filename)
      Mosquito::MockUpload.new(filename)
    end
    
    # Checks that Camping sent us a cookie to attach a session
    def assert_session_started
      assert_not_nil @cookies["camping_sid"], 
        "The session ID cookie was empty although session should have started"
    end
    
    # The reverse of +assert_session_started+
    def assert_no_session
      assert_nil @cookies["camping_sid"], 
        "A session cookie was sent although this should not happen"
    end
    
    private
      def extract_redirection_url
        loc = @response.headers['Location']
        path_seg = @response.headers['Location'].path.gsub(%r!/#{@class_name_abbr.downcase}!, '')
        loc.query ? (path_seg + "?" + loc.query).to_s : path_seg.to_s
      end
      
      def relativize_url!(url)
        return unless url =~ /^([a-z]+):\//
        p = URI.parse(url)
        unless p.host == @request.domain
          raise ::Mosquito::NonLocalRequest, 
          "You tried to callout to #{p} which is outside of the test domain"
        end
        url.replace(p.path + (p.query.blank ? '' : "?#{p.query}"))
      end
  end
  
  # Used to test the models - no infrastructure will be created for running the request
  class ModelTest < Test
    def test_dummy; end #:nodoc
  end
  
  # Deprecated but humane
  UnitTest = ModelTest
  FunctionalTest = WebTest
end
