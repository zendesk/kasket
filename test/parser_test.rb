require_relative "helper"
require 'kasket/query_parser'

describe Kasket::QueryParser do
  def parse(options)
    scope = Post
    options.each do |k,v|
      scope = case k
      when :conditions then scope.where(v)
      else
        scope.send(k, v)
      end
    end
    scope.to_kasket_query
  end

  describe "Parsing" do
    before do
      @parser = Kasket::QueryParser.new(Post)
    end

    it "not support conditions with number as column (e.g. 0 = 1)" do
      assert !parse(:conditions => "0 = 1")
    end

    it "not support conditions with number as column and parans (e.g. 0 = 1)" do
      assert !parse(:conditions => "(0 = 1)")
    end

    it "not support :order" do
      assert !parse(:conditions => "id = 1", :order => "xxx")
    end

    it 'not support IN queries in combination with other conditions' do
      assert !parse(:conditions => {:id => [1,2,3], :is_active => true})
    end

    it "extract conditions" do
      kasket_query = parse(:conditions => {:title => 'red', :blog_id => 1})
      assert_equal [[:blog_id, "1"], [:title, "red"]], kasket_query[:attributes]
    end

    it "extract conditions with parans that do not surround" do
      kasket_query = parse(:conditions => "(title = 'red') AND (blog_id = 1)")
      assert !kasket_query
    end

    it "extract required index" do
      assert_equal [:blog_id, :title], parse(:conditions => {:title => 'red', :blog_id => 1})[:index]
    end

    it "only support queries against its model's table" do
      assert !parse(:conditions => {'blogs.id' => 2}, :from => 'apples')
    end

    it "support cachable queries" do
      assert parse(:conditions => {:id => 1})
      assert parse(:conditions => {:id => 1}, :limit => 1)
    end

    it "support IN queries on id" do
      assert_equal [[:id, ['1', '2', '3']]], parse(:conditions => {:id => [1,2,3]})[:attributes]
    end

    it "not support IN queries on other attributes" do
      assert !parse(:conditions => {:hest => [1,2,3]})
    end

    it "support vaguely formatted queries" do
      assert @parser.parse('SELECT * FROM "posts" WHERE (title = red AND blog_id = big)')
    end

    describe "extract options" do
      it "provide the limit" do
        assert_equal nil, parse(:conditions => {:id => 2})[:limit]
        assert_equal 1, parse(:conditions => {:id => 2}, :limit => 1)[:limit]
      end
    end

    describe "unsupported queries" do
      it "include advanced limits" do
        assert !parse(:conditions => {:title => 'red', :blog_id => 1}, :limit => 2)
      end

      it "include joins" do
        assert !parse(:conditions => {:title => 'test', 'apple.tree_id' => 'posts.id'}, :from => ['posts', 'apple'])
        assert !parse(:conditions => {:title => 'test'}, :joins => :comments)
      end

      it "include specific selects" do
        assert !parse(:conditions => {:title => 'red'}, :select => :id)
      end

      it "include offset" do
        assert !parse(:conditions => {:title => 'red'}, :limit => 1, :offset => 2)
      end

      it "include order" do
        assert !parse(:conditions => {:title => 'red'}, :order => :title)
      end

      it "include the OR operator" do
        assert !parse(:conditions => "title = 'red' OR blog_id = 1")
      end
    end

    describe "key generation" do
      it "include the table name and version" do
        kasket_query = parse(:conditions => {:id => 1})
        assert_match(/^kasket-#{Kasket::Version::PROTOCOL}\/R#{ActiveRecord::VERSION::MAJOR}#{ActiveRecord::VERSION::MINOR}\/posts\/version=#{POST_VERSION}\//, kasket_query[:key])
      end

      it "include all indexed attributes" do
        kasket_query = parse(:conditions => {:id => 1})
        assert_match(/id=1$/, kasket_query[:key])

        kasket_query = parse(:conditions => {:id => 1, :blog_id => 2})
        assert_match(/blog_id=2\/id=1$/, kasket_query[:key])

        kasket_query = parse(:conditions => {:id => 1, :title => 'title'})
        assert_match(/id=1\/title='title'$/, kasket_query[:key])
      end

      it "generate multiple keys on IN queries" do
        keys = parse(:conditions => {:id => [1,2]})[:key]
        assert_instance_of(Array, keys)
        assert_match(/id=1$/, keys[0])
        assert_match(/id=2$/, keys[1])
      end

      describe "when limit 1" do
        it "add /first to the key if the index does not include id" do
          assert_match(/title='a'\/first$/, parse(:conditions => {:title => 'a'}, :limit => 1)[:key])
        end

        it "not add /first to the key when the index includes id" do
          assert_match(/id=1$/, parse(:conditions => {:id => 1}, :limit => 1)[:key])
        end
      end
    end
  end
end
