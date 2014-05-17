require_relative "helper"

describe "transactions" do
  describe "normal" do
    it "have kasket disabled" do
      assert_equal true, Post.use_kasket?
      Post.transaction do
        assert_equal false, Post.use_kasket?
      end
      assert_equal true, Post.use_kasket?
    end
  end

  describe "nested" do
    before { Comment.has_kasket }
    it "disable kasket" do
      Post.transaction do
        assert_equal false,  Comment.use_kasket?
        assert_equal false, Post.use_kasket?
        Comment.transaction do
          assert_equal false, Post.use_kasket?
          assert_equal false, Comment.use_kasket?
        end
      end
    end
  end
end
