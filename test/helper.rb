require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/rg'
require 'mocha/setup'
require 'active_record'
require 'logger'
require 'timecop'

ENV['TZ'] = 'UTC'
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.logger = Logger.new(StringIO.new)

require 'active_record/fixtures'
require 'kasket'

Kasket.setup

ActiveSupport.test_order = :random if ActiveSupport.respond_to?(:test_order=)

class ActiveSupport::TestCase
  # all tests inherit from this
  extend MiniTest::Spec::DSL
  register_spec_type(self) { |desc| true }

  include ActiveRecord::TestFixtures
  self.fixture_path = File.dirname(__FILE__) + "/fixtures/"
  fixtures :all

  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
    end
  end

  self.use_transactional_fixtures = true

  self.use_instantiated_fixtures  = false

  setup :clear_cache
  def clear_cache
    Kasket.cache.clear
  end
end

module Rails
  class << self
    def cache
      @cache ||= ActiveSupport::Cache::MemoryStore.new
    end

    def logger
      ActiveRecord::Base.logger
    end

    def env
      'development'
    end
  end
end

require './test/test_models'
POST_VERSION = Post.column_names.join.sum
COMMENT_VERSION = Comment.column_names.join.sum
