require File.dirname(__FILE__) + '/helper'

class DirtyTest < ActiveSupport::TestCase
  fixtures :blogs, :posts

  should "clear the indices when a dirty method is called" do
    post = Post.first

    Post.cache { pots = Post.find(post.id) }
    assert(Rails.cache.read(post.kasket_key))

    post.make_dirty!

    assert_nil(Rails.cache.read(post.kasket_key))
  end
end
