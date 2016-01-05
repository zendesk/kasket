require 'active_record'
require 'active_support'

require 'kasket/version'

module Kasket
  autoload :ReadMixin,              'kasket/read_mixin'
  autoload :WriteMixin,             'kasket/write_mixin'
  autoload :DirtyMixin,             'kasket/dirty_mixin'
  autoload :QueryParser,            'kasket/query_parser'
  autoload :ConfigurationMixin,     'kasket/configuration_mixin'
  autoload :Query,                  'kasket/query'
  autoload :Visitor,                'kasket/visitor'
  autoload :SelectManagerMixin,     'kasket/select_manager_mixin'
  autoload :RelationMixin,          'kasket/relation_mixin'
  autoload :Cache,                  'kasket/cache'

  CONFIGURATION = {:max_collection_size => 100, :write_through => false}

  module_function

  def setup(options = {})
    return if ActiveRecord::Base.respond_to?(:has_kasket)

    CONFIGURATION[:max_collection_size] = options[:max_collection_size] if options[:max_collection_size]
    CONFIGURATION[:write_through] = options[:write_through] if options[:write_through]

    ActiveRecord::Base.extend(Kasket::ConfigurationMixin)

    if defined?(ActiveRecord::Relation)
      ActiveRecord::Relation.send(:include, Kasket::RelationMixin)
      Arel::SelectManager.send(:include, Kasket::SelectManagerMixin)
    end
  end

  def self.cache_store=(options)
    @cache_store = Cache.new(ActiveSupport::Cache.lookup_store(options))
  end

  def self.cache
    @cache_store ||= Cache.new(Rails.cache)
  end
end
