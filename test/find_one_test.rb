require_relative "helper"

describe "find one" do
  fixtures :blogs, :posts

  it "cache find(id) calls" do
    post = Post.first
    Kasket.cache.write(post.kasket_key, nil)

    assert_equal(post, Post.find(post.id))
    assert(Kasket.cache.read(post.kasket_key))

    Post.connection.expects(:select_all).never
    assert_equal(post, Post.find(post.id))
  end

  it "only cache on indexed attributes" do
    Kasket.cache.expects(:read).twice
    Post.find_by_id(1)
    Post.where(:blog_id => 2).find_by_id 1

    Kasket.cache.expects(:read).never
    Post.where(:blog_id => 2).first # partially indexed
    Post.where(:updated_at => Time.at(0)).find_by_id(1) # partially indexed
  end

  it "not use cache when using the :select option" do
    post = Post.first
    assert_nil(Kasket.cache.read(post.kasket_key))

    Post.select('title').find(post.id)
    assert_nil(Kasket.cache.read(post.kasket_key))

    Post.find(post.id)
    assert(Kasket.cache.read(post.kasket_key))

    Kasket.cache.expects(:read)
    Post.find(post.id)

    Kasket.cache.expects(:read).never
    Post.select('title').find(post.id)
  end

  it "respect scope" do
    post = Post.find(Post.first.id)
    other_blog = Blog.where("id != #{post.blog_id}").first

    assert(Kasket.cache.read(post.kasket_key))

    assert_raise(ActiveRecord::RecordNotFound) do
      other_blog.posts.find(post.id)
    end
  end

  it "use same scope when finding on has_many" do
    post = Blog.first.posts.first
    blog = Blog.first
    Kasket.cache.clear

    post = blog.posts.find(post.id)
    key  = post.kasket_key.sub(%r{(/id=#{post.id})}, "/blog_id=#{Blog.first.id}\\1")
    assert(Kasket.cache.read(key))
  end

  it "uses different caches when being unscoped" do
    DefaultComment.find(1) # put it into cache
    DefaultComment.where(id: 1).update_all(public: false) # simulate db changing

    assert DefaultComment.find(1).public # read from old cache
    DefaultComment.unscoped { refute DefaultComment.find(1).public } # read from different cache -> correct value
  end
end
