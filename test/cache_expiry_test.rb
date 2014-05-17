require_relative "helper"

describe "cache expiry" do
  fixtures :blogs, :posts

  describe "a cached object" do
    before do
      post = Post.first
      @post = Post.find(post.id)

      assert(Kasket.cache.read(@post.kasket_key))
    end

    it "be removed from cache when deleted" do
      @post.destroy
      assert_nil(Kasket.cache.read(@post.kasket_key))
    end

    it "clear all indices for instance when deleted" do
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "id=#{@post.id}")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")
      Kasket.cache.expects(:delete).never

      @post.destroy
    end

    it "be removed from cache when updated" do
      @post.title = "new_title"
      @post.save
      assert_nil(Kasket.cache.read(@post.kasket_key))
    end

    it "clear all indices for instance when updated" do
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "id=#{@post.id}")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")
      Kasket.cache.expects(:delete).never

      @post.title = "new_title"
      @post.save
    end
  end
end
