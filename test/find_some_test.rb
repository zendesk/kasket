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

  describe "with dalli_allow_true_class_response" do
    before do
      Kasket::CONFIGURATION[:dalli_allow_true_class_response] = true # default value
    end

    after do
      Kasket::CONFIGURATION[:dalli_allow_true_class_response] = true # default value
    end

    it "does not raise error when set to false" do
      post = Post.first
      Kasket.cache.write(post.kasket_key, true)

      assert_equal(true, Kasket.cache.read(post.kasket_key))
      Kasket::CONFIGURATION[:dalli_allow_true_class_response] = false
      p = Post.find(post.id)
      assert_equal(p, post)
      assert_equal(true, Kasket.cache.read(post.kasket_key))
    end

    it "raise error when dalli_allow_true_class_response set to true explicitly" do
      post = Post.first
      Kasket.cache.write(post.kasket_key, true)
      assert_equal(true, Kasket.cache.read(post.kasket_key))

      assert_raise NoMethodError do
        Post.find(post.id)
      end
    end
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
