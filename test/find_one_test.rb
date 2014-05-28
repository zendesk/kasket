require_relative "helper"

describe "find one" do
  fixtures :blogs, :posts

  it "cache find(id) calls" do
    post = Post.first
    Kasket.cache.write(post.kasket_key, nil)

    assert_equal(post, Post.find(post.id))
    assert(Kasket.cache.read(post.kasket_key))

    Post.expects(:find_by_sql_without_kasket).never
    assert_equal(post, Post.find(post.id))
  end

  it "only cache on indexed attributes" do
    Kasket.cache.expects(:read).twice
    Post.find_by_id(1)
    Post.where(:blog_id => 2).find_by_id 1

    Kasket.cache.expects(:read).never
    Post.where(:blog_id => 2).first
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
end
