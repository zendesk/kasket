# frozen_string_literal: true
require_relative "helper"

describe Kasket::ReadMixin do
  fixtures :authors

  describe "find by sql with kasket" do
    before do
      if ActiveRecord::VERSION::STRING >= '4.2.0'
        @post_database_result = {
          'id' => 1, 'title' => 'Hello', "author_id" => nil, "blog_id" => nil, "poly_id" => nil,
          "poly_type" => nil, "created_at" => nil, "updated_at" => nil, "big_id" => nil
        }
        @comment_database_result = [
          { 'id' => 1, 'body' => 'Hello', "post_id" => nil, "created_at" => nil, "updated_at" => nil, "public" => nil },
          { 'id' => 2, 'body' => 'World', "post_id" => nil, "created_at" => nil, "updated_at" => nil, "public" => nil }
        ]
      else
        @post_database_result = { 'id' => 1, 'title' => 'Hello' }
        @comment_database_result = [
          { 'id' => 1, 'body' => 'Hello' },
          { 'id' => 2, 'body' => 'World' }
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

    describe "instrumentation" do
      let(:callback) do
        lambda do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)

          @notification_received = true
          @payload = event.payload
          @record_count = event.payload[:record_count]
          @class_name = event.payload[:class_name]
        end
      end

      before do
        @notification_received = false
        @payload = nil
        @record_count = 0
        @class_name = ""
      end

      describe "a single record" do
        before do
          Kasket.cache.write("#{Post.kasket_key_prefix}id=1", @post_database_result)
        end

        it "does not call the db" do
          Post.expects(:find_by_sql_without_kasket).never

          Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
        end

        it "sends an ActiveSupport::Notification" do
          ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
            Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
          end

          assert @notification_received
          assert_equal 1, @record_count
          assert_equal "Post", @class_name
        end
      end

      describe "an array of records" do
        let(:posts) { ["#{Post.kasket_key_prefix}id=1", "#{Post.kasket_key_prefix}id=2"] }

        before do
          Kasket.cache.write("#{Comment.kasket_key_prefix}post_id=1", posts)
        end

        it "does not call the db" do
          Comment.expects(:find_by_sql_without_kasket).never

          Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)')
        end

        it "sends an ActiveSupport::Notification" do
          ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
            Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)')
          end

          assert @notification_received
          assert_equal 2, @record_count
          assert_equal "Comment", @class_name
        end
      end

      describe "a cache miss" do
        it "calls the db" do
          Post.expects(:find_by_sql_without_kasket).once.returns(@post_records)

          Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
        end

        it "does not send a notification" do
          Post.stubs(:find_by_sql_without_kasket).returns(@post_records)

          ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
            Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
          end

          refute @notification_received
          assert_equal 0, @record_count
          assert_equal "", @class_name
        end
      end

      it "emits the same payload as rails" do
        Post.unstub(:find_by_sql_without_kasket)

        ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
          Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
        end

        assert @notification_received
        rails_payload = @payload
        @notification_received = false
        @payload = nil

        Kasket.cache.write("#{Post.kasket_key_prefix}id=1", @post_database_result)
        Post.expects(:find_by_sql_without_kasket).never

        ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
          Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
        end

        assert @notification_received
        assert_equal rails_payload, @payload
      end
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
      assert_equal(@comment_records, records.sort_by(&:id))
    end

    describe "modifying results" do
      before do
        Kasket.cache.write("#{Post.kasket_key_prefix}id=1", 'id' => 1, 'title' => "asd")
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
    assert_equal({ 'sex' => 'male' }, author.metadata)

    author = Author.find(author.id)
    assert_equal({ 'sex' => 'male' }, author.metadata)
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

  it "expires the cache when the expires_in option is set" do
    old = ExpiringComment.find(1).updated_at
    ExpiringComment.where(id: 1).update_all(updated_at: Time.now + 10.seconds)
    assert_equal ExpiringComment.find(1).updated_at, old # caching works

    Timecop.travel(Time.now + 6.minutes) do
      assert ExpiringComment.find(1).updated_at != old # cache expired
    end
  end

  describe "pending saved records in a transaction" do
    before do
      @post = Post.find(1)
      assert_not_nil Kasket.cache.read(@post.kasket_key)
    end

    it "returns saved version" do
      ActiveRecord::Base.transaction do
        @post.title = "new_title"
        @post.save!

        assert_equal @post.title, Post.find(@post.id).title
        assert_equal @post.title, Post.where(id: @post.id).first.title
        assert_equal @post.title, Post.all.detect { |x| x.id == @post.id }.title
        assert_equal @post.title, Post.find_by_sql("SELECT * FROM `posts` WHERE id = 1").first.title
      end
    end

    it "finds cached when searching by column" do
      assert_equal Post.where(title: 'no_comments').first.title, 'no_comments'
      Post.expects(:find_by_sql_without_kasket).never
      assert_equal Post.where(title: 'no_comments').first.title, 'no_comments'
    end

    it "returns nothing if object destroyed" do
      ActiveRecord::Base.transaction do
        @post.destroy
        assert_raises ActiveRecord::RecordNotFound do
          Post.find(@post.id)
        end
        assert_equal [], Post.where(id: @post.id)
        assert_nil Post.all.detect { |x| x.id == @post.id }
        assert_equal [], Post.find_by_sql("SELECT * FROM `posts` WHERE id = 1")
      end
    end
  end
end
