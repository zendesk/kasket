require_relative "helper"

describe "dirty" do
  fixtures :blogs, :posts

  def assert_cleared
    post = Post.first

    Post.cache { pots = Post.find(post.id) }
    assert Kasket.cache.read(post.kasket_key)

    yield post

    refute Kasket.cache.read(post.kasket_key)
  end

  it "clear the indices when a dirty method is called" do
    assert_cleared { |p| p.make_dirty! }
  end

  it "clears the indices when touch is called" do
    assert_cleared do |p|
      p.touch

      # Kludge - in test, after_commit callback runs too late.
      p.save if ActiveRecord::VERSION::MAJOR == 3
    end
  end

  it "clear the indices when update_column is called" do
    assert_cleared { |p| p.update_column :title, 'xxxx' }
  end

  it "clear the indices when update_attribute is called" do
    assert_cleared { |p| p.update_attribute :title, 'xxxx' }
  end

  it "supports blocks" do
    x = false
    assert_cleared { |p| p.method_with_block { x = true } }
    assert x
  end
end
