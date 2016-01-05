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
      Kasket.cache.expects(:delete).never

      @post.destroy
    end

    it "is removed from cache when updated" do
      @post.title = "new_title"
      @post.save
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
      Kasket.cache.expects(:delete).never

      @post.title = "new_title"
      @post.save
    end

    describe "between after_save and after_commit" do
      it "blacklists the cache keys" do
        Post.transaction do
          @post.title = "new_title"
          keys = @post.kasket_keys
          @post.save
          Kasket.cache.send(:blacklist).must_equal Set.new(keys)
        end
      end

      it "clears the blacklist after commit" do
        Post.transaction do
          @post.title = "new_title"
          @post.save
        end
        Kasket.cache.send(:blacklist).must_equal Set.new
      end

      it "clears the blacklist after rollback" do
        Post.transaction do
          @post.title = "new_title"
          @post.save
          raise ActiveRecord::Rollback
        end
        Kasket.cache.send(:blacklist).must_equal Set.new
      end

      it "blocks Kasket.cache.read of blacklisted keys" do
        Rails.cache.expects(:read).never
        Post.transaction do
          @post.title = "new_title"
          @post.save
          assert_nil Kasket.cache.read(@post.kasket_key)
        end
      end

      it "blocks Kasket.cache.read_multi with blacklisted keys" do
        Rails.cache.expects(:read_multi).with().returns({})
        Post.transaction do
          @post.title = "new_title"
          @post.save
          assert_equal ({}), Kasket.cache.read_multi(@post.kasket_key)
        end
      end

      it "blocks Kasket.cache.write to blacklisted keys" do
        Rails.cache.expects(:write).never
        Post.transaction do
          @post.title = "new_title"
          @post.save
          Kasket.cache.write(@post.kasket_key, "foo")
        end
      end
    end

    describe "when :write_through is true" do
      before do
        Kasket::CONFIGURATION[:write_through] = true
      end

      it "is updated in cache when updated" do
        @post.title = "new_title"
        @post.save
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
        Kasket.cache.expects(:delete).never

        @post.title = "new_title"
        @post.save
      end

      after do
        Kasket::CONFIGURATION[:write_through] = false
      end
    end
  end
end
