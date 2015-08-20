require_relative "helper"

describe Kasket::ReadMixin do
  fixtures :authors

  describe "find by sql with kasket" do
    before do
      if ActiveRecord::VERSION::STRING >= '4.2.0'
        @post_database_result = { 'id' => 1, 'title' => 'Hello', "author_id" => nil, "blog_id" => nil, "poly_id" => nil, "poly_type" => nil, "created_at" => nil, "updated_at" => nil }
        @comment_database_result = [
          { 'id' => 1, 'body' => 'Hello', "post_id" => nil, "created_at" => nil, "updated_at" => nil },
          { 'id' => 2, 'body' => 'World', "post_id" => nil, "created_at" => nil, "updated_at" => nil }
        ]
      else
        @post_database_result = { 'id' => 1, 'title' => 'Hello' }
        @comment_database_result = [
          { 'id' => 1, 'body' => 'Hello'},
          { 'id' => 2, 'body' => 'World'}
        ]
      end

      @post_records = [Post.send(:instantiate, @post_database_result)]
      Post.stubs(:find_by_sql_without_kasket).returns(@post_records)
      @comment_records = @comment_database_result.map {|r| Comment.send(:instantiate, r)}
      Comment.stubs(:find_by_sql_without_kasket).returns(@comment_records)
    end

    it "handle unsupported sql" do
      Kasket.cache.expects(:read).never
      Kasket.cache.expects(:write).never
      assert_equal @post_records, Post.find_by_sql_with_kasket('select unsupported sql statement')
    end

    it "read results" do
      Kasket.cache.write("#{Post.kasket_key_prefix}id=1", @post_database_result)
      assert_equal @post_records, Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
    end

    it "support sql with ?" do
      Kasket.cache.write("#{Post.kasket_key_prefix}id=1", @post_database_result)
      assert_equal @post_records, Post.find_by_sql(['SELECT * FROM `posts` WHERE (id = ?)', 1])
    end

    it "store results in kasket" do
      Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')

      assert_equal @post_database_result, Kasket.cache.read("#{Post.kasket_key_prefix}id=1")
    end

    it "store multiple records in cache" do
      Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)')
      stored_value = Kasket.cache.read("#{Comment.kasket_key_prefix}post_id=1")
      assert_equal(["#{Comment.kasket_key_prefix}id=1", "#{Comment.kasket_key_prefix}id=2"], stored_value)
      assert_equal(@comment_database_result, stored_value.map {|key| Kasket.cache.read(key)})

      Comment.expects(:find_by_sql_without_kasket).never
      records = Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)')
      assert_equal(@comment_records, records.sort {|c1, c2| c1.id <=> c2.id})
    end

    describe "modifying results" do
      before do
        Kasket.cache.write("#{Post.kasket_key_prefix}id=1", {'id' => 1, 'title' => "asd"})
        @sql = 'SELECT * FROM `posts` WHERE (id = 1)'
        @record = Post.find_by_sql(@sql).first
        assert_equal "asd", @record.title # read from cache ?
        attributes = @record.instance_variable_get(:@attributes)
        attributes = attributes.send(:attributes).instance_variable_get(:@values) unless attributes.is_a?(Hash)
        attributes['id'] = 3
      end

      it "not impact other queries" do
        same_record = Post.find_by_sql(@sql).first

        assert_not_equal @record, same_record
      end

    end

  end

  it "support serialized attributes" do
    author = authors(:mick)

    author = Author.find(author.id)
    assert_equal({'sex' => 'male'}, author.metadata)

    author = Author.find(author.id)
    assert_equal({'sex' => 'male'}, author.metadata)
  end

  it "not store time with zone" do
    Time.use_zone(ActiveSupport::TimeZone.all.first) do
      post = posts(:no_comments)
      post = Post.find(post.id)
      object = Kasket.cache.read("#{Post.kasket_key_prefix}id=#{post.id}")

      actual = object["created_at"]
      actual = object["created_at"].to_s(:db) if object["created_at"].is_a?(Time)

      assert_equal "2013-10-14 15:30:00", actual, object["created_at"].class
    end
  end

end
