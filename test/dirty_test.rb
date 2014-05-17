require File.expand_path("helper", File.dirname(__FILE__))

describe "dirty" do
  fixtures :blogs, :posts

  it "clear the indices when a dirty method is called" do
    post = Post.first

    Post.cache { pots = Post.find(post.id) }
    assert(Kasket.cache.read(post.kasket_key))

    post.make_dirty!

    assert_nil(Kasket.cache.read(post.kasket_key))
  end
end
