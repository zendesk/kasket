# frozen_string_literal: true
erb_config = IO.read(File.expand_path("database.yml", File.dirname(__FILE__)))
yaml_config = ERB.new(erb_config).result

ActiveRecord::Base.configurations =
  YAML.load(yaml_config) # rubocop:disable Security/YAMLLoad

configs = ActiveRecord::Base.configurations
config = if configs.respond_to? :find_db_config # TODO: clean up after 5.2 dropped
  c = configs.find_db_config("test")
  if c.respond_to? :configuration_hash # 6.1 deprecation
    c.configuration_hash
  else
    c.config.with_indifferent_access
  end
else
  configs["test"].with_indifferent_access
end

ActiveRecord::Base.establish_connection(config.merge(database: nil))
ActiveRecord::Base.connection.recreate_database(config[:database], config)
ActiveRecord::Base.establish_connection(config)

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

  self.ignored_columns = ["ignored_column"]

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
