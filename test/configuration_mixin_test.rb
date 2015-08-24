require_relative "helper"
require "digest/md5"

describe "configuration mixin" do
  describe "Generating cache keys" do
    it "not choke on empty numeric attributes" do
      expected_cache_key = "#{Post.kasket_key_prefix}blog_id=null"
      query_attributes   = [ [:blog_id, ''] ]

      assert_equal expected_cache_key, Post.kasket_key_for(query_attributes)
    end

    it "not fail on unknown columns" do
      expected_cache_key = "#{Post.kasket_key_prefix}does_not_exist=111"
      query_attributes   = [ [:does_not_exist, '111'] ]

      assert_equal expected_cache_key, Post.kasket_key_for(query_attributes)
    end

    it "not generate keys longer that 255" do
      Post.stubs(:quoted_value_for_column).returns((1..999).to_a.join.to_s)
      assert(Post.kasket_key_for([:blog_id, 1]).size < 255)
    end

    it "not generate keys with spaces" do
      query_attributes = [ [:title, 'this key has speces'] ]

      assert(!(Post.kasket_key_for(query_attributes) =~ /\s/))
    end

    it "downcase string attributes" do
      query_attributes = [ [:title, 'ThIs'] ]
      expected_cache_key = "#{Post.kasket_key_prefix}title='this'"

      assert_equal expected_cache_key, Post.kasket_key_for(query_attributes)
    end

    it "build correct prefix" do
      assert_equal "kasket-#{Kasket::Version::PROTOCOL}/R#{ActiveRecord::VERSION::MAJOR}#{ActiveRecord::VERSION::MINOR}/posts/version=#{POST_VERSION}/", Post.kasket_key_prefix
    end
  end
end
