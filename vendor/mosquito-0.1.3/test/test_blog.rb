require File.dirname(__FILE__) + "/../lib/mosquito"
require File.dirname(__FILE__) + "/../public/blog"
Blog.create
include Blog::Models

class TestBlog < Camping::FunctionalTest
  fixtures :blog_posts, :blog_users, :blog_comments

  def setup
    super
    # We inject the session into the blog here to prevent it from attaching to Bare as well. Normally this
    # should not happen but we need to take sides to test for sessioneless Camping compliance.
    unless @sesion_set
      Blog.send(:include, Camping::Session)
      ActiveRecord::Migration.suppress_messages do
        ::Camping::Models::Session.create_schema
      end
      @sesion_set = true
    end
  end

  def test_cookies
    get '/cookies'
    assert_cookie 'awesome_cookie', 'camping for good'
    assert_equal @state.awesome_data, 'camping for good'
    get '/'
    assert_equal @state.awesome_data, 'camping for good'
  end

  def test_cookies_persisted_across_requests_and_escaping_properly_handled
    @cookies["asgård"] = 'Wøbble'
    get '/cookies'
    assert_equal 'asgård=W%C3%B8bble', @request['HTTP_COOKIE'], "The cookie val shouldbe escaped"
    assert_response :success
    assert_equal 'Wøbble', @cookies["asgård"]

    get '/'
    assert_equal @state.awesome_data, 'camping for good'
    assert_equal 'Wøbble', @cookies["asgård"]
  end

  def test_index
    get
    assert_response :success
    assert_match_body %r!>blog<!
    assert_not_equal @state.awesome_data, 'camping for good'
    assert_kind_of Array, @assigns[:posts]
    assert_kind_of Post, assigns[:posts].first
  end

  def test_view
    get '/view/1'
    assert_response :success
    assert_match_body %r!The quick fox jumped over the lazy dog!
  end

  def test_styles
    get 'styles.css'
    assert_match_body %r!Utopia!
  end

  def test_edit_should_require_login
    get '/edit/1'
    assert_response :success
    assert_match_body 'login'
  end

  def test_login
    post 'login', :username => 'quentin', :password => 'password'
    assert_match_body 'login success'
  end

  def test_comment
    assert_difference(Comment) {
      post 'comment', {
        :post_username => 'jim',
        :post_body => 'Nice article.',
        :post_id => 1
      }
      assert_response :redirect
      assert_redirected_to '/view/1'
    }
  end

  def test_sage_advice_raised_when_getting_with_files
    assert_raise(Mosquito::SageAdvice) do
      get '/view/1', :afile => Mosquito::MockUpload.new("apic.jpg")
    end
  end

  def test_session_roundtrip_across_successive_requests
    get '/session-roundtrip'
    assert @state.has_key?(:flag_in_session)

    assert_session_started
    post '/session-roundtrip'
    assert @state.has_key?(:second_flag), "The :second_flag key in the session gets set only if the previous flag was present"
    assert_session_started
  end

  def test_request_uri_has_no_double_slashes
    get '/session-roundtrip'
    assert_equal "/blog/session-roundtrip", @request['REQUEST_URI']
  end

  def test_follow_redirect
    get '/redirector'
    assert_response :redirect

    assert_redirected_to '/sniffer?one=two'

    follow_redirect
    roundtipped_params = YAML::load(StringIO.new(@response.body))
    ref = {"one" => "two"}.with_indifferent_access
    assert_equal ref, roundtipped_params
  end

  def test_request_honors_verbatim_query_string_and_passed_params
    assert_nothing_raised do
      get '/sniffer?one=2&foo=baz', :taing => 44
    end

    roundtripped = YAML::load(StringIO.new(@response.body.to_s))
    ref = {"taing"=>"44", "one" => "2", "foo" => "baz"}
    assert_equal ref, roundtripped
  end

  def test_uplaod_gets_a_quick_uplaod_handle
    file = upload("pic.jpg")
    assert_kind_of Mosquito::MockUpload, file
  end

  def test_intrinsic_methods
    # This WILL use mocks when we get to it from more pressing matters
    delete '/rest'
    assert_equal 'Called delete', @response.body

    put '/rest'
    assert_equal 'Called put', @response.body
  end

  def calling_with_an_absolute_url_should_relativize
    assert_equal 'test.host', @request.domain
    put 'http://test.host/blog/rest'
    assert_nothing_raised do
      assert_equal 'Called put', @response.body
    end
  end

  def test_calling_with_an_absolute_url_outside_of_the_default_test_host_must_raise
    assert_equal 'test.host', @request.domain
    assert_raise(Mosquito::NonLocalRequest) do
      put 'http://yahoo.com/blog/rest'
    end
  end

  def test_calling_with_an_absolute_url_outside_of_the_custom_test_host_must_raise
    @request.domain = 'foo.bar'
    assert_raise(Mosquito::NonLocalRequest) do
      put 'http://test.host/blog/rest'
    end
  end

end

class TestPost < Camping::ModelTest

  fixtures :blog_posts, :blog_users, :blog_comments

  def test_fixtures_path_is_relative_to_the_testcase
    assert_equal 'test/fixtures/', self.class.fixture_path
  end

  def test_create
    post = create
    assert post.valid?
  end

  def test_assoc
    post = Post.find :first
    assert_kind_of User, post.user
    assert_equal 1, post.user.id
  end

  def test_destroy
    original_count = Post.count
    Post.destroy 1
    assert_equal original_count - 1, Post.count
  end

  private

  def create(options={})
    Post.create({
      :user_id => 1,
      :title => "Title",
      :body => "Body"
    }.merge(options))
  end

end

class TestUser < Camping::ModelTest

  fixtures :blog_posts, :blog_users, :blog_comments

  def test_create
    user = create
    assert user.valid?
  end

  def test_required
    user = create(:username => nil)
    deny user.valid?
    assert_not_nil user.errors.on(:username)
  end

  test "should require username" do
    assert_no_difference(User, :count) do
      User.create(:username => nil)
    end
  end

  private

  def create(options={})
    User.create({
      :username => 'godfrey',
      :password => 'password'
    }.merge(options))
  end

end
