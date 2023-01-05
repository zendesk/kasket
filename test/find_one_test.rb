# frozen_string_literal: true
require_relative "helper"

describe "find one" do
  fixtures :blogs, :posts

  def assert_key(key)
    assert Kasket.cache.read(key), "Expected Kasket cache to contain a value for the key #{key}"
  end

  def refute_key(key)
    assert_nil Kasket.cache.read(key), "Expected Kasket cache not to contain a value for the key #{key}"
  end

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
    Post.where(blog_id: 2).find_by_id 1

    Kasket.cache.expects(:read).never
    Post.where(blog_id: 2).first # partially indexed
    Post.where(updated_at: Time.at(0)).find_by_id(1) # partially indexed
  end

  it "not use cache when using the :select option" do
    post = Post.first
    refute_key post.kasket_key

    Post.select('title').find(post.id)
    refute_key post.kasket_key

    Post.find(post.id)
    assert_key post.kasket_key

    Kasket.cache.expects(:read)
    Post.find(post.id)

    Kasket.cache.expects(:read).never
    Post.select('title').find(post.id)
  end

  it "uses cache when using the :select option with all columns" do
    post = Post.first
    refute_key post.kasket_key

    Post.select(Post.column_names).find(post.id)
    assert_key post.kasket_key
  end

  it "doesn't use cache when using the :select option with all columns including ignored columns" do
    post = Post.first
    refute_key post.kasket_key

    Post.select(Post.column_names + Post.ignored_columns).find(post.id)
    refute_key post.kasket_key
  end

  it "respect scope" do
    post = Post.find(Post.first.id)
    other_blog = Blog.where("id != #{post.blog_id}").first

    assert_key post.kasket_key

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
    assert_key key
  end

  it "uses different caches when being unscoped" do
    DefaultComment.find(1) # put it into cache
    DefaultComment.where(id: 1).update_all(public: false) # simulate db changing

    assert DefaultComment.find(1).public # read from old cache
    DefaultComment.unscoped { refute DefaultComment.find(1).public } # read from different cache -> correct value
  end
end
