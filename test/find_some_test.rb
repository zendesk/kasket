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
    Post.connection.expects(:select_all).never
    Post.find(@post1.id, @post2.id)
  end

  it "use cache for where :id => xxx calls" do
    Post.connection.expects(:select_all).never
    Post.where(:id => [@post1.id, @post2.id]).to_a
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
    Post.connection.expects(:select_all).never
    found_posts = Post.find(@post1.id, @post2.id)
    assert_equal [@post1, @post2].map(&:id).sort, found_posts.map(&:id).sort
  end

  describe "unfound" do
    it "ignore unfound when using find_all_by_id" do
      found_posts = Post.where(:id => [@post1.id, 1231232]).to_a
      assert_equal [@post1.id], found_posts.map(&:id)
    end

    it "not ignore unfound when using find" do
      assert_raise ActiveRecord::RecordNotFound do
        Post.find(@post1.id, 1231232)
      end
    end
  end
end
