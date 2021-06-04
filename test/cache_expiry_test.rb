# frozen_string_literal: true
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
      assert_equal @post.reload.title, 'sneaky'
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

  describe 'a cached association' do
    let(:post) do
      posts(:has_two_comments)
    end

    let(:comment1) do
      comments(:few_comments_1)
    end

    let(:comment2) do
      comments(:few_comments_2)
    end

    it 'has two comments' do
      assert_equal post.comments, [comment1, comment2]
    end

    describe 'when loaded and then deleted' do
      before do
        post.comments
        comment1.delete
      end

      it 'retains two comments' do
        assert_equal post.comments, [comment1, comment2]
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, [comment2]
      end
    end

    describe 'when loaded and then destroyed' do
      before do
        post.comments
        comment2.delete
      end

      it 'retains two comments' do
        assert_equal post.comments, [comment1, comment2]
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, [comment1]
      end
    end

    describe 'when deleted via the collection' do
      before do
        post.comments.delete(comment1)
      end

      it 'removes comment' do
        assert_equal post.comments, [comment2]
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, [comment2]
      end
    end

    describe 'when destroyed via the collection' do
      before do
        post.comments.destroy(comment2)
      end

      it 'removes comment' do
        assert_equal post.comments, [comment1]
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, [comment1]
      end
    end

    describe 'when all destroyed via the collection' do
      before do
        post.comments.destroy_all
      end

      it 'removes all comments' do
        assert_equal post.comments, []
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, []
      end
    end

    describe 'when deleted and parent is updated' do
      before do
        post.comments
        comment1.delete
        post.touch
      end

      it 'reflects changes' do
        assert_equal post.comments, [comment2]
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, [comment2]
      end
    end

    describe 'when destroyed and parent is updated' do
      before do
        post.comments
        comment2.destroy
        post.touch
      end

      it 'reflects changes' do
        assert_equal post.comments, [comment1]
      end

      it 'reflects updates after reload' do
        assert_equal post.reload.comments, [comment1]
      end
    end
  end
end
