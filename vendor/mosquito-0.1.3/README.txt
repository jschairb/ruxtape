=Mosquito, for Bug-Free Camping

A testing helper for those times when you go Camping.
Apply on the face, neck, and any exposed areas such as your 
Models and Controllers. Scrub gently, observe the results.

== Usage

Make a few files and directories like this:

  public/
    blog.rb
  test/
    test_blog.rb
    fixtures/
       blog_comments.yml
       blog_posts.yml
       blog_users.yml

Setup <b>test_blog.rb</b> like this:

  require 'rubygems'
  require 'mosquito'
  require File.dirname(__FILE__) + "/../public/blog"
  
  Blog.create
  include Blog::Models
  
  class TestBlog < Camping::WebTest
    
    fixtures :blog_posts, :blog_users, :blog_comments
    
    def setup
      super
      # Do other stuff here
    end
    
    test "should get index" do
      get
      assert_response :success
      assert_match_body %r!>blog<!
    end
    
    test "should get view" do
      get '/view/1'
      assert_response :success
      assert_kind_of Article, @assigns[:article]
      assert_match_body %r!The quick fox jumped over the lazy dog!
    end
    
    test "should change profile" do
      @request['SERVER_NAME'] = 'jonh.blogs.net'
      post '/change-profile', :new_photo => upload("picture.jpg")
      assert_response :success
      assert_match_body %r!The pic has been uploaded!
    end
  end

  # A unit test
  class TestPost < Camping::ModelTest

    fixtures :blog_posts, :blog_users, :blog_comments

    test "should create" do
      post = Post.create( :user_id => 1, 
                          :title => "Title", 
                          :body => "Body")
      assert post.valid?
    end

    test "should be associated with User" do
      post = Post.find :first
      assert_kind_of User, post.user
      assert_equal 1, post.user.id
    end

  end

You can also use old-school methods like <tt>def test_create</tt>, but we think this way is much more natural. 

Mosquito includes Jay Fields' <tt>dust</tt> gem for the nice <tt>test</tt> method which allows more descriptive test names and has the added benefit of detecting those times when you try to write two tests with the same name. Ruby will otherwise silently overwrite duplicate test names without warning, which can give a false sense of security.

== Details

Inherit from Camping::WebTest or Camping::ModelTest. If you define <tt>setup</tt>, 
be sure to call <tt>super</tt> so the parent class can do its thing.

You should also call the <tt>MyApp.create</tt> method if you have one, <b>yourself</b>. You will also
need to <tt>include MyApp::Models</tt> at the top of your test file if you want to use 
Models in your assertions directly (without going through MyApp::Models::SomeModel).

Make fixtures in <b>test/fixtures</b>. Remember that Camping models use the name of 
the mount plus the model name: <b>blog_posts</b> for the <b>Post</b> model.

See <b>blog_test.rb</b> for an example of both Web and Model tests.

Mosquito is one file, just like your app (right?), so feel free to ship it included with the app itself
to simplify testing.

== Warning: You are Camping, not Rail-riding

These directives are highly recommended when using Mosquito:

* Test files start with <b>test_</b> (test_blog.rb). Test classes start with <b>Test</b> (TestBlog).
* Model and Controller test classes can both go in the same file.
* The popular automated test runner <tt>autotest</tt> ships with a handler for Mosquito. Install the ZenTest gem and run the <tt>autotest</tt> command in the same folder as the <tt>public</tt> and <tt>test</tt> directories.
* A Sqlite3 :memory: database is automatically used for tests that require a database.

You can run your tests by executing the test file with Ruby or by running the autotest command with no arguments (from the ZenTest gem).

  ruby test/test_blog.rb
  
or
  
  autotest

== RSpec

Do you prefer RSpec syntax? You can get halfway there by putting this include in your test file:

  require 'spec/test_case_adapter'

Then you can use <tt>should</tt> and <tt>should_not</tt> on objects inside your tests.

== Authors

Geoffrey Grosenbach http://topfunky.com, with a supporting act 
from the little fairy http://julik.nl and the evil multipart generator
conceived by http://maxidoors.ru. 