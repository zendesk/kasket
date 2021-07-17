# frozen_string_literal: true
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

  CONFIGURATION = { # rubocop:disable Style/MutableConstant
    max_collection_size: 100,
    write_through: false,
    default_expires_in: nil,
    dalli_allow_true_class_response: true
  }

  module_function

  def setup(options = {})
    return if ActiveRecord::Base.respond_to?(:has_kasket)

    CONFIGURATION[:max_collection_size] = options[:max_collection_size] if options[:max_collection_size]
    CONFIGURATION[:write_through]       = options[:write_through]       if options[:write_through]
    CONFIGURATION[:default_expires_in]  = options[:default_expires_in]  if options[:default_expires_in]
    CONFIGURATION[:dalli_allow_true_class_response] = !!options[:dalli_allow_true_class_response] if options.key?(:dalli_allow_true_class_response)

    ActiveRecord::Base.extend(Kasket::ConfigurationMixin)

    if defined?(ActiveRecord::Relation)
      ActiveRecord::Relation.include Kasket::RelationMixin
      Arel::SelectManager.include Kasket::SelectManagerMixin
    end
  end

  def self.cache_store=(options)
    @cache_store = ActiveSupport::Cache.lookup_store(options)
  end

  def self.cache_store
    @cache_store ||= Rails.cache
  end

  # Alias cache_store to cache
  class << self
    alias_method :cache, :cache_store
  end

  # Keys are the records being saved.
  # Values are either the saved record, or nil if the record has been destroyed.
  def self.pending_records
    Thread.current[:kasket_pending_records]
  end

  def self.add_pending_record(record, destroyed = false)
    Thread.current[:kasket_pending_records] ||= {}
    Thread.current[:kasket_pending_records][record] = destroyed ? nil : record
  end

  def self.clear_pending_records
    Thread.current[:kasket_pending_records] = nil
  end
end
