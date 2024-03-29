# frozen_string_literal: true
module Kasket
  module ReadMixin
    def self.extended(base)
      class << base
        alias_method :find_by_sql_without_kasket, :find_by_sql
        alias_method :find_by_sql, :find_by_sql_with_kasket
      end
    end

    def find_by_sql_with_kasket(sql, binds = [], *restargs, **kwargs, &blk)
      if use_kasket?
        query = if sql.respond_to?(:to_kasket_query)
          if ActiveRecord::VERSION::STRING < '5.2'
            sql.to_kasket_query(self, binds.map(&:value_for_database))
          else
            sql.to_kasket_query(self)
          end
        else
          kasket_parser.parse(sanitize_sql(sql))
        end
      end

      if query && has_kasket_index_on?(query[:index])
        if query[:key].is_a?(Array)
          filter_pending_records(find_by_sql_with_kasket_on_id_array(query[:key]), &blk)
        else
          if value = Kasket.cache.read(query[:key])
            # Identified a specific edge case where memcached server returns 0x00 binary protocol response with no data
            # when the node is being rebooted which causes the Dalli memcached client to return a TrueClass object instead of nil
            # see: https://github.com/petergoldstein/dalli/blob/31dabf19d3dd94b348a00a59fe5a7b8fa80ce3ad/lib/dalli/server.rb#L520
            # and: https://github.com/petergoldstein/dalli/issues/390
            #
            # The code in this first condition of TrueClass === true  will
            # skip the kasket cache for these specific objects and go directly to SQL for retrieval.
            result_set = if value.is_a?(TrueClass)
              find_by_sql_without_kasket(sql, binds, *restargs, **kwargs, &blk)
            elsif value.is_a?(Array)
              # The data from the Kasket cache is a list of keys to other Kasket entries.
              # This usually happens when we're trying to load a collection association,
              # e.g. a list of comments using their post_id in the query.
              # Do not report a cache hit yet, and defer it until we've verified that at
              # least one of the retrieved keys is actually in the cache.
              filter_pending_records(find_by_sql_with_kasket_on_id_array(value))
            else
              # Direct cache hit for the key.
              Events.report("cache_hit", self)
              filter_pending_records(Array.wrap(value).collect { |record| instantiate(record.dup, &blk) })
            end

            payload = {
              record_count: result_set.length,
              class_name: to_s
            }

            ActiveSupport::Notifications.instrument('instantiation.active_record', payload) { result_set }
          else
            store_in_kasket(query[:key], find_by_sql_without_kasket(sql, binds, *restargs, **kwargs, &blk))
          end
        end
      else
        find_by_sql_without_kasket(sql, binds, *restargs, **kwargs, &blk)
      end
    end

    def find_by_sql_with_kasket_on_id_array(keys, &blk)
      key_attributes_map = Kasket.cache.read_multi(*keys)

      found_keys, missing_keys = keys.partition {|k| key_attributes_map[k] }
      # Only report a cache hit if at least some keys were found in the cache.
      Events.report("cache_hit", self) if found_keys.any?

      found_keys.each {|k| key_attributes_map[k] = instantiate(key_attributes_map[k].dup, &blk) }
      key_attributes_map.merge!(missing_records_from_db(missing_keys))

      key_attributes_map.values.compact
    end

    protected

    def filter_pending_records(records)
      if pending_records = Kasket.pending_records
        records.map { |record| pending_records.fetch(record, record) }.compact
      else
        records
      end
    end

    def missing_records_from_db(missing_keys)
      return {} if missing_keys.empty?

      id_key_map = Hash[missing_keys.map {|key| [key.split('=').last.to_i, key] }]

      found = without_kasket { where(id: id_key_map.keys).to_a }
      found.each(&:store_in_kasket)
      Hash[found.map {|record| [id_key_map[record.id], record] }]
    end

    def store_in_kasket(key, records)
      if records.size == 1
        records.first.store_in_kasket(key)
      elsif records.empty?
        ActiveRecord::Base.logger.debug("[KASKET] would have stored an empty resultset") if ActiveRecord::Base.logger
      elsif records.size <= Kasket::CONFIGURATION[:max_collection_size]
        if records.all?(&:kasket_cacheable?)
          instance_keys = records.map(&:store_in_kasket)
          Kasket.cache.write(key, instance_keys)
        end
      end
      records
    end
  end
end
