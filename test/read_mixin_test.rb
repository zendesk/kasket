# frozen_string_literal: true
require_relative "helper"

describe Kasket::ReadMixin do
  fixtures :authors

  before do
    @post_database_result = {
      'id' => 1, 'title' => 'Hello', "author_id" => nil, "blog_id" => nil, "poly_id" => nil,
      "poly_type" => nil, "created_at" => nil, "updated_at" => nil, "big_id" => nil, "ignored_column" => nil
    }
    @comment_database_result = [
      { 'id' => 1, 'body' => 'Hello', "post_id" => 1, "created_at" => nil, "updated_at" => nil, "public" => nil },
      { 'id' => 2, 'body' => 'World', "post_id" => 1, "created_at" => nil, "updated_at" => nil, "public" => nil }
    ]
    @post_records = [Post.instantiate(@post_database_result)]
    @comment_records = @comment_database_result.map { |r| Comment.instantiate(r) }
  end

  describe "find by sql with kasket" do
    before do
      Post.stubs(:find_by_sql_without_kasket).returns(@post_records)
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

    describe "it can retrieve one or multiple records through the high-level AR model API (Kasket query[:key] is an Array)" do
      before do
        Kasket.cache.write("#{Comment.kasket_key_prefix}id=1", @comment_database_result[0])
        Kasket.cache.write("#{Comment.kasket_key_prefix}id=2", @comment_database_result[1])

        Kasket.cache.write("#{Comment.kasket_key_prefix}post_id=1", [
          "#{Comment.kasket_key_prefix}id=1",
          "#{Comment.kasket_key_prefix}id=2"
        ])
      end

      specify "one record" do
        Comment.expects(:find_by_sql_without_kasket).never

        out = Comment.find(1)
        assert_equal @comment_records[0], out

        out = Comment.find_by(id: 1)
        assert_equal @comment_records[0], out

        out = Comment.where(id: 2).first
        assert_equal @comment_records[1], out
      end

      specify "multiple records" do
        Comment.expects(:find_by_sql_without_kasket).never

        out = Comment.find(1, 2)
        assert_equal @comment_records, out

        out = Comment.where(id: [1, 2]).to_a
        assert_equal @comment_records, out

        out = Comment.where(post_id: 1).to_a
        assert_equal @comment_records, out
      end
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
          Post.unstub(:find_by_sql_without_kasket)
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
        let(:comments) { ["#{Comment.kasket_key_prefix}id=1", "#{Comment.kasket_key_prefix}id=2"] }

        before do
          Comment.unstub(:find_by_sql_without_kasket)
          Kasket.cache.write("#{Comment.kasket_key_prefix}post_id=1", comments)
          @comment_database_result.each { |c| Kasket.cache.write("#{Comment.kasket_key_prefix}id=#{c['id']}", c) }
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

      Comment.unstub(:find_by_sql_without_kasket)
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

        case attributes.class.name # LazyAttributeSet is 6.1+
        when "Hash"
          # do nothing
        when "ActiveModel::LazyAttributeSet"
          attributes = attributes.send(:values)
        when "ActiveModel::AttributeSet", "ActiveRecord::AttributeSet"
          attributes = attributes.send(:attributes).instance_variable_get(:@values)
        else
          raise "unknown type: %p" % [attributes]
        end

        attributes['id'] = 3
      end

      it "not impact other queries" do
        same_record = Post.find_by_sql(@sql).first

        assert_not_equal @record, same_record
      end
    end

    describe "emitting stats" do
      before do
        @previous = Kasket::CONFIGURATION[:events_callback]
        Kasket::Events.remove_instance_variable(:@fn) if Kasket::Events.instance_variable_defined?(:@fn)

        @emitted_events = []
        callback = proc do |event, ar_klass|
          @emitted_events << [event, ar_klass]
        end

        Kasket::CONFIGURATION[:events_callback] = callback
      end

      after { Kasket::CONFIGURATION[:events_callback] = @previous }

      describe "event: cache_hit" do
        it "is emitted when retrieving one record from the cache" do
          Kasket.cache.write("#{Post.kasket_key_prefix}id=1", @post_database_result)

          assert_empty @emitted_events
          Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
          assert_equal 1, @emitted_events.length
          assert_equal ["cache_hit", Post], @emitted_events[0]
        end

        it "is emitted when retrieving multiple records from the cache" do
          # The Comment-by-post-id key points to the two Comment-by-id keys.
          # Each Comment-by-id key contains its own record data.
          Kasket.cache.write("#{Comment.kasket_key_prefix}post_id=1", [
            "#{Comment.kasket_key_prefix}id=1",
            "#{Comment.kasket_key_prefix}id=2"
          ])
          Kasket.cache.write("#{Comment.kasket_key_prefix}id=1", @comment_database_result[0])
          Kasket.cache.write("#{Comment.kasket_key_prefix}id=2", @comment_database_result[1])

          assert_empty @emitted_events
          Comment.find_by_sql('SELECT * FROM `comments` WHERE (post_id = 1)')
          assert_equal 1, @emitted_events.length
          assert_equal ["cache_hit", Comment], @emitted_events[0]
        end

        it "is NOT emitted when nothing is in the cache the cache" do
          assert_nil Kasket.cache.read("#{Post.kasket_key_prefix}id=1")

          assert_empty @emitted_events
          Post.find_by_sql('SELECT * FROM `posts` WHERE (id = 1)')
          # Other events might have been emitted.
          @emitted_events.each do |emitted_event|
            refute_equal ["cache_hit", Post], emitted_event
          end
        end
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

    describe "when finding multiple records (Kasket query[:key] is an Array)" do
      before do
        Kasket.cache.write("#{Comment.kasket_key_prefix}id=1", @comment_database_result[0])
        Kasket.cache.write("#{Comment.kasket_key_prefix}id=2", @comment_database_result[1])

        Kasket.cache.write("#{Comment.kasket_key_prefix}post_id=1", [
          "#{Comment.kasket_key_prefix}id=1",
          "#{Comment.kasket_key_prefix}id=2"
        ])

        @comment = @comment_records[0]
      end

      it "returns the saved version" do
        ActiveRecord::Base.transaction do
          @comment.body = "new body"
          @comment.save!

          assert_equal "new body", Comment.find(1, 2)[0].body
          assert_equal "new body", Comment.where(id: [1, 2]).to_a[0].body
          assert_equal "new body", Comment.where(post_id: 1).to_a[0].body
        end
      end

      it "returns nothing if object destroyed" do
        ActiveRecord::Base.transaction do
          @comment.destroy

          assert_raises ActiveRecord::RecordNotFound do
            Comment.find(1, 2)
          end

          assert_equal 1, Comment.where(id: [1, 2]).to_a.length
          refute_equal @comment.id, Comment.where(id: [1, 2]).to_a[0]

          assert_equal 1, Comment.where(post_id: 1).to_a.length
          refute_equal @comment.id, Comment.where(post_id: 1).to_a[0]
        end
      end
    end
  end

  describe 'instantiate is passed blocks' do
    let(:post) { posts(:has_many_comments) }
    let(:comment_id) { post.comments.last.id }

    before do
      # populate cache
      post.comments.find(comment_id)
      # clear association cache
      post.reload

      Post.without_kasket do
        assert_equal post.object_id, post.comments.find(comment_id).post.object_id
      end
    end

    it 'instantiates inverse associations' do
      assert_equal post.object_id, post.comments.find(comment_id).post.object_id
    end
  end
end
