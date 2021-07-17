# frozen_string_literal: true
require_relative "helper"

describe "find some" do
  fixtures :blogs, :posts

  before do
    @post1 = Post.first
    @post2 = Post.last
    Post.find(@post1.id, @post2.id)
    assert Kasket.cache.read(@post1.kasket_key)
    assert Kasket.cache.read(@post2.kasket_key)
  end

  it "use cache for find(id, id) calls" do
    Post.expects(:find_by_sql_without_kasket).never
    Post.find(@post1.id, @post2.id)
  end

  it "use cache for find([id, id]) calls" do
    Post.expects(:find_by_sql_without_kasket).never
    Post.find([@post1.id, @post2.id])
  end

  it "use cache for find(id, id) calls with string values" do
    Post.expects(:find_by_sql_without_kasket).never
    Post.find(@post1.id.to_s, @post2.id.to_s)
  end

  it "use cache for find([id, id]) calls with string values" do
    Post.expects(:find_by_sql_without_kasket).never
    Post.find([@post1.id.to_s, @post2.id.to_s])
  end

  it "use cache for where :id => xxx calls" do
    Post.expects(:find_by_sql_without_kasket).never
    Post.where(id: [@post1.id, @post2.id]).to_a
  end

  it "use cache for where :id => xxx calls with string values" do
    Post.expects(:find_by_sql_without_kasket).never
    Post.where(id: [@post1.id.to_s, @post2.id.to_s]).to_a
  end

  it "cache when found using find(id, id) calls" do
    Kasket.cache.delete(@post1.kasket_key)
    Kasket.cache.delete(@post2.kasket_key)

    Post.find(@post1.id, @post2.id)

    assert Kasket.cache.read(@post1.kasket_key)
    assert Kasket.cache.read(@post2.kasket_key)
  end

  it "only lookup the records that are not in the cache" do
    Kasket.cache.delete(@post2.kasket_key)

    # has to lookup post2 via db
    Post.expects(:find_by_sql_without_kasket).returns([@post2])
    found_posts = Post.find(@post1.id, @post2.id)
    assert_equal [@post1, @post2].map(&:id).sort, found_posts.map(&:id).sort

    # now all are cached
    Post.expects(:find_by_sql_without_kasket).never
    found_posts = Post.find(@post1.id, @post2.id)
    assert_equal [@post1, @post2].map(&:id).sort, found_posts.map(&:id).sort
  end

  it "does not raise error when cache is poisoned with TrueClass" do
    post = Post.first
    Kasket.cache.write(post.kasket_key, true) # This used to kerplunk things when AWS elasticcache rebooted

    assert_equal(true, Kasket.cache.read(post.kasket_key))

    p = Post.find(post.id)
    assert_equal(p, post)
    assert_equal(true, Kasket.cache.read(post.kasket_key))
  end

  describe "unfound" do
    it "ignore unfound when using find_all_by_id" do
      found_posts = Post.where(id: [@post1.id, 1231232]).to_a
      assert_equal [@post1.id], found_posts.map(&:id)
    end

    it "not ignore unfound when using find" do
      assert_raise ActiveRecord::RecordNotFound do
        Post.find(@post1.id, 1231232)
      end
    end
  end
end
