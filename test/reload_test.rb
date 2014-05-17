require_relative "helper"

describe "reload" do
  describe "Reloading a model" do
    before do
      @post = Post.first
      assert @post
      assert @post.title
    end

    it "clear local cache" do
      Kasket.expects(:clear_local)
      @post.reload
    end
  end
end
