require_relative "helper"

describe "cache expiry" do
  fixtures :blogs, :posts

  describe "a cached object" do
    before do
      post = Post.first
      @post = Post.find(post.id)

      assert(Kasket.cache.read(@post.kasket_key))
    end

    it "is removed from cache when deleted" do
      @post.destroy
      assert_nil(Kasket.cache.read(@post.kasket_key))
    end

    it "clears all indices for instance when deleted" do
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "id=#{@post.id}")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")

      @post.destroy
    end

    it "is removed from cache when updated" do
      @post.title = "new_title"
      @post.save!
      assert_nil(Kasket.cache.read(@post.kasket_key))
    end

    it "is removed from cache when touched" do
      @post.touch
      assert_nil(Kasket.cache.read(@post.kasket_key))
    end

    it "loads a fresh copy when reload is called" do
      Post.where(id: @post.id).update_all(title: 'sneaky')
      @post.reload.title.must_equal 'sneaky'
    end

    it "clears all indices for instance when updated" do
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "id=#{@post.id}")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")

      @post.title = "new_title"
      @post.save!
    end

    it "clears all indices for instance when using update_column" do
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "id=#{@post.id}")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'/first")
      Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")

      @post.update_column :title, "new_title"
    end

    if ActiveRecord::VERSION::MAJOR >= 4
      it "clears all indices for instance when using update_columns" do
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "id=#{@post.id}")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'/first")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")

        @post.update_columns title: "new_title"
      end
    end

    describe "when :write_through is true" do
      before do
        Kasket::CONFIGURATION[:write_through] = true
      end

      it "is updated in cache when updated" do
        @post.title = "new_title"
        @post.save!
        assert_equal @post.attributes, Kasket.cache.read(@post.kasket_key)
      end

      it "is updated in cache when touched" do
        @post.touch
        assert_equal @post.attributes, Kasket.cache.read(@post.kasket_key)
      end

      it "writes id key and clears indices for instance when updated" do
        Kasket.cache.expects(:write).with(Post.kasket_key_prefix + "id=#{@post.id}", anything, nil)
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='#{@post.title}'/first")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "title='new_title'/first")
        Kasket.cache.expects(:delete).with(Post.kasket_key_prefix + "blog_id=#{@post.blog_id}/id=#{@post.id}")

        @post.title = "new_title"
        @post.save!
      end

      after do
        Kasket::CONFIGURATION[:write_through] = false
      end
    end
  end
end
