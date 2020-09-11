# frozen_string_literal: true
require_relative "helper"
require "digest/md5"

describe "configuration mixin" do
  describe "Generating cache keys" do
    it "not choke on empty numeric attributes" do
      expected_cache_key = "#{Post.kasket_key_prefix}blog_id=null"
      query_attributes   = [[:blog_id, '']]

      assert_equal expected_cache_key, Post.kasket_key_for(query_attributes)
    end

    it "not fail on unknown columns" do
      expected_cache_key = "#{Post.kasket_key_prefix}does_not_exist=111"
      query_attributes   = [[:does_not_exist, '111']]

      assert_equal expected_cache_key, Post.kasket_key_for(query_attributes)
    end

    it "not generate keys longer that 255" do
      Post.stubs(:kasket_quoted_value_for_column).returns((1..999).to_a.join.to_s)
      assert(Post.kasket_key_for([:blog_id, 1]).size < 255)
    end

    it "not generate keys with spaces" do
      query_attributes = [[:title, 'this key has speces']]

      assert(Post.kasket_key_for(query_attributes) !~ /\s/)
    end

    it "downcase string attributes" do
      query_attributes = [[:title, 'ThIs']]
      expected_cache_key = "#{Post.kasket_key_prefix}title='this'"

      assert_equal expected_cache_key, Post.kasket_key_for(query_attributes)
    end

    it "build correct prefix" do
      protocol = Kasket::Version::PROTOCOL
      ar_version = "#{ActiveRecord::VERSION::MAJOR}#{ActiveRecord::VERSION::MINOR}"
      assert_equal "kasket-#{protocol}/R#{ar_version}/posts/version=#{POST_VERSION}/", Post.kasket_key_prefix
    end
  end

  describe "kasket_ttl" do
    describe "with an explicit TTL" do
      it "returns the local TTL" do
        assert_equal 5.minutes, ExpiringComment.kasket_ttl
      end
    end

    describe "without an explicit TTL" do
      it "falls back to the global" do
        previous = Kasket::CONFIGURATION[:default_expires_in]
        Kasket::CONFIGURATION[:default_expires_in] = 86401
        assert_equal 86401, DefaultComment.kasket_ttl
      ensure
        Kasket::CONFIGURATION[:default_expires_in] = previous
      end
    end
  end
end
