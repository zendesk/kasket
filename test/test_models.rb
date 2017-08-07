# frozen_string_literal: true
ActiveRecord::Base.configurations =
  YAML.load(IO.read(File.expand_path("database.yml", File.dirname(__FILE__)))) # rubocop:disable Security/YAMLLoad

config = ActiveRecord::Base.configurations['test']

ActiveRecord::Base.establish_connection(config.merge('database' => nil))
ActiveRecord::Base.connection.recreate_database(config['database'], config)
ActiveRecord::Base.establish_connection(:test)

load(File.dirname(__FILE__) + "/schema.rb")

class Comment < ActiveRecord::Base
  belongs_to :post
  has_one :author, through: :post

  has_kasket_on :post_id
end

class Author < ActiveRecord::Base
  serialize :metadata
  has_many :posts

  has_kasket
end

class Post < ActiveRecord::Base
  belongs_to :blog
  belongs_to :author
  has_many :comments
  belongs_to :poly, polymorphic: true

  has_kasket
  has_kasket_on :title
  has_kasket_on :blog_id, :id

  def make_dirty!
    self.updated_at = Time.now
    self.class.connection.execute("UPDATE posts SET updated_at = '#{updated_at.utc.to_s(:db)}' WHERE id = #{id}")
  end

  def method_with_block
    yield
  end

  kasket_dirty_methods :make_dirty!, :method_with_block
end

class Blog < ActiveRecord::Base
  has_many :posts
  has_many :comments, through: :posts
end

class ExpiringComment < ActiveRecord::Base
  self.table_name = 'comments'

  has_kasket
  kasket_expires_in 5.minutes
end

class DefaultComment < ActiveRecord::Base
  self.table_name = 'comments'

  default_scope { where(public: true) }

  has_kasket_on :public, :id
end
