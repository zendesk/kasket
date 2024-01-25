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
  autoload :Events,                 'kasket/events'

  CONFIGURATION = { # rubocop:disable Style/MutableConstant
    max_collection_size: 100,
    write_through: false,
    default_expires_in: nil,
    events_callback: nil,
  }

  module_function

  # Configure Kasket.
  #
  # @param [Hash] options the configuration options for Kasket.
  # @option options [Integer] :max_collection_size max size limit for a cacheable
  #   collection of records.
  # @option options [Boolean] :write_through
  # @option options [Integer, nil] :default_expires_in the cache TTL.
  # @option options [#call] :events_callback a callable object used to instrument
  #   Kasket operations. It is invoked with two arguments: the name of the event,
  #   as a String, and the Klass of the ActiveRecord model the event is about.
  #
  def setup(options = {})
    return if ActiveRecord::Base.respond_to?(:has_kasket)

    CONFIGURATION[:max_collection_size] = options[:max_collection_size] if options[:max_collection_size]
    CONFIGURATION[:write_through]       = options[:write_through]       if options[:write_through]
    CONFIGURATION[:default_expires_in]  = options[:default_expires_in]  if options[:default_expires_in]
    CONFIGURATION[:events_callback]     = options[:events_callback]     if options[:events_callback]

    ActiveRecord::Base.extend(Kasket::ConfigurationMixin)
    ActiveRecord::Relation.include(Kasket::RelationMixin)
    Arel::SelectManager.include(Kasket::SelectManagerMixin)
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
