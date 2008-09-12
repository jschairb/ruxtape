
module Blog::Models
  def self.schema(&block)
    @@schema = block if block_given?
    @@schema
  end

  class Post < Base; belongs_to :user; end
  class Comment < Base; belongs_to :user; end
  class User < Base; validates_presence_of :username; end
end
