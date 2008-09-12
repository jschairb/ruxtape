
module Blog::Controllers
  class Index < R '/'
    def get
      @posts = Post.find :all
      render :index
    end
  end

  class Add
    def get
      unless @state.user_id.blank?
        @user = User.find @state.user_id
        @post = Post.new
      end
      render :add
    end
    def post
      post = Post.create({
        :title => input.post_title,
        :body => input.post_body,
        :user_id => @state.user_id
      })
      redirect View, post
    end
  end

  class Info < R '/info/(\d+)', '/info/(\w+)/(\d+)', '/info', '/info/(\d+)/(\d+)/(\d+)/([\w-]+)'
    def get(*args)
      div do
        code args.inspect; br; br
        code ENV.inspect; br
        code "Link: #{R(Info, 1, 2)}"
      end
    end
  end

  class View < R '/view/(\d+)'
    def get post_id
      @post = Post.find post_id
      @comments = Models::Comment.find_all_by_post_id post_id
      render :view
    end
  end

  class Edit < R '/edit/(\d+)', '/edit'
    def get post_id
      unless @state.user_id.blank?
        @user = User.find @state.user_id
      end
      @post = Post.find post_id
      render :edit
    end

    def post
      @post = Post.find input.post_id
      @post.update_attributes :title => input.post_title, :body => input.post_body
      redirect View, @post
    end
  end

  class Comment
    def post
      Models::Comment.create({
        :username => input.post_username,
        :body => input.post_body,
        :post_id => input.post_id
      })
      redirect View, input.post_id
    end
  end

  class Login
    def post
      @user = User.find(:first, {
        :conditions => [
          'username = ? AND password = ?',
          input.username,
          input.password
        ]
      })

      if @user
        @login = 'login success !'
        @state.user_id = @user.id
      else
        @login = 'wrong user name or password'
      end
      render :login
    end
  end

  class Cookies < R '/cookies'
    def get
      @cookies.awesome_cookie = 'camping for good'
      @state.awesome_data = 'camping for good'
      @posts = Post.find(:all)
      render :index
    end
  end

  class Logout
    def get
      @state.user_id = nil
      render :logout
    end
  end

  class Style < R '/styles.css'
    def get
      @headers["Content-Type"] = "text/css; charset=utf-8"
      @body = %{
        body {
          font-family: Utopia, Georgia, serif;
        }
        h1.header {
          background-color: #fef;
          margin: 0; padding: 10px;
        }
        div.content {
          padding: 10px;
        }
      }
    end
  end

  # The following is introduced as a means to quickly test roundtrips
  class SessionRoundtrip < R('/session-roundtrip')
    def get
      @state[:flag_in_session] = "This is a flag"
    end

    def post
      if @state[:flag_in_session]
        @state[:second_flag] = "This is a second flag"
      end
      return ''
    end
  end

  class Redirector < R('/redirector')
    def get
      redirect '/blog/sniffer?one=two'
    end
  end

  class Sniffer < R('/sniffer')
    def get
      input.to_hash.to_yaml
    end
    alias_method :post, :get
  end

  class Restafarian < R('/rest')
    def delete
      return "Called delete"
    end

    def put
      return "Called put"
    end
  end
end
