
module Blog::Views

  def layout
    html do
      head do
        title 'blog'
        link :rel => 'stylesheet', :type => 'text/css', :href => '/styles.css', :media => 'screen'
      end
      body do
        h1.header { a 'blog', :href => R(Index) }
        div.content do
          self << yield
        end
      end
    end
  end

  def index
    if @posts.empty?
      p 'No posts found.'
      p { a 'Add', :href => R(Add) }
    else
      for post in @posts
        _post(post)
      end
    end
  end

  def login
    p { b @login }
    p { a 'Continue', :href => R(Add) }
  end

  def logout
    p "You have been logged out."
    p { a 'Continue', :href => R(Index) }
  end

  def add
    if @user
      _form(post, :action => R(Add))
    else
      _login
    end
  end

  def edit
    if @user
      _form(post, :action => R(Edit))
    else
      _login
    end
  end

  def view
    _post(post)

    p "Comment for this post:"
    for c in @comments
      h1 c.username
      p c.body
    end

    form :action => R(Comment), :method => 'post' do
      label 'Name', :for => 'post_username'; br
      input :name => 'post_username', :type => 'text'; br
      label 'Comment', :for => 'post_body'; br
      textarea :name => 'post_body' do; end; br
        input :type => 'hidden', :name => 'post_id', :value => post.id
        input :type => 'submit'
      end
    end

    # partials
    def _login
      form :action => R(Login), :method => 'post' do
        label 'Username', :for => 'username'; br
        input :name => 'username', :type => 'text'; br

        label 'Password', :for => 'password'; br
        input :name => 'password', :type => 'text'; br

        input :type => 'submit', :name => 'login', :value => 'Login'
      end
    end

    def _post(post)
      h1 post.title
      p post.body
      p do
        a "Edit", :href => R(Edit, post)
        a "View", :href => R(View, post)
      end
    end

    def _form(post, opts)
      p do
        text "You are logged in as #{@user.username} | "
        a 'Logout', :href => R(Logout)
      end
      form({:method => 'post'}.merge(opts)) do
        label 'Title', :for => 'post_title'; br
        input :name => 'post_title', :type => 'text', :value => post.title; br

        label 'Body', :for => 'post_body'; br
        textarea post.body, :name => 'post_body'; br

        input :type => 'hidden', :name => 'post_id', :value => post.id
        input :type => 'submit'
      end
    end
  end
