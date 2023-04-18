# frozen_string_literal: true
require_relative "helper"

describe "cacheable" do
  describe "#store_in_kasket" do
    it "only cache object that are kasket_cacheable?" do
      post = Post.instantiate('id' => 1, 'title' => 'Hello')

      post.expects(:kasket_cacheable?).returns(true)
      Kasket.cache.expects(:write).once
      post.store_in_kasket

      post.expects(:kasket_cacheable?).returns(false)
      Kasket.cache.expects(:write).never
      post.store_in_kasket
    end
  end

  describe "caching of results of find" do
    before do
      @post_database_result = { 'id' => 1, 'title' => 'Hello' }
      @post_records = [Post.instantiate(@post_database_result)]
      Post.stubs(:find_by_sql_without_kasket).returns(@post_records)

      @comment_database_result = [{ 'id' => 1, 'body' => 'Hello' }, { 'id' => 2, 'body' => 'World' }]
      @comment_records = @comment_database_result.map { |r| Comment.instantiate(r) }
      Comment.stubs(:find_by_sql_without_kasket).returns(@comment_records)
    end

    describe "with just one result" do
      it "write result in cache if it is kasket_cacheable?" do
        Post.any_instance.expects(:kasket_cacheable?).returns(true)
        Kasket.cache.expects(:write).once
        Post.find(1)
      end

      it "not write result in cache if it is not kasket_cacheable?" do
        Post.any_instance.expects(:kasket_cacheable?).returns(false)
        Kasket.cache.expects(:write).never
        Post.find(1)
      end
    end

    describe "with several results" do
      it "write result in cache if all results are kasket_cacheable?" do
        Comment.any_instance.stubs(:kasket_cacheable?).returns(true)
        Kasket.cache.expects(:write).times(@comment_records.size + 1)
        Comment.where(post_id: 1).to_a
      end

      it "not write result in cache if any of them are not kasket_cacheable?" do
        @comment_records[0].expects(:kasket_cacheable?).returns(true)
        @comment_records[1].expects(:kasket_cacheable?).returns(false)
        Kasket.cache.expects(:write).never
        Comment.where(post_id: 1).to_a
      end
    end
  end
end
