require File.dirname(__FILE__) + "/../lib/mosquito"
require File.dirname(__FILE__) + "/../public/bare"

# When you got a few Camping apps in one process you actually install the session
# for all of them simply by including. We want to test operation without sessions so we
# call this app Bare, which comes before Blog.
class TestBare < Camping::FunctionalTest

  test "should get index with success" do
    get '/'
    assert_response :success
    assert_no_session
    assert_match_body %r!Charles!
  end

  def test_get_without_arguments_should_give_us_the_index_page
    get
    assert_response :success
    assert_match_body %r!Charles!
  end

  test "should get page with success" do
    get '/sample'
    assert_response :success
    assert_no_session
    assert_match_body %r!<p>A sample page</p>!
  end

  def test_request_uri_preserves_query_vars
    get '/sample', :somevar => 10
    assert_equal '/bare/sample?somevar=10', @request['REQUEST_URI']
  end

  test "should assert_no_match_body" do
    get '/sample'
    assert_no_match_body /Rubber\s+Bubblegum\s+Burt Reynolds\s+Hippopotamus/
  end

  test "should return error" do
    get '/error'
    assert_response :error
  end

  test "should return 404 error" do
    get '/error404'
    assert_response 404
  end

  def test_assigning_verbatim_post_payload
    post '/sample', 'foo=bar&plain=flat'
    @request.body.rewind
    assert_equal 'foo=bar&plain=flat', @request.body.read
  end

  test "should redirect" do
    get '/redirect'
    assert_redirected_to '/faq'
  end

  # test "should send file" do
  #   get '/file'
  #   assert_response :success
  #   # TODO
  # end

end
