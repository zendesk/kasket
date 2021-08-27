# frozen_string_literal: true
module Kasket
  module ReadMixin
    def self.extended(base)
      class << base
        alias_method :find_by_sql_without_kasket, :find_by_sql
        alias_method :find_by_sql, :find_by_sql_with_kasket
      end
    end

    # *args can be replaced with (sql, *args) once we stop supporting Rails < 5.2
    def find_by_sql_with_kasket(*args)
      sql = args[0]

      if use_kasket?
        query = if sql.respond_to?(:to_kasket_query)
          if ActiveRecord::VERSION::MAJOR < 5
            sql.to_kasket_query(self, args[1])
          else
            if ActiveRecord::VERSION::STRING < '5.2'
              sql.to_kasket_query(self, args[1].map(&:value_for_database))
            else
              sql.to_kasket_query(self)
            end
          end
        else
          kasket_parser.parse(sanitize_sql(sql))
        end
      end

      if query && has_kasket_index_on?(query[:index])
        if query[:key].is_a?(Array)
          find_by_sql_with_kasket_on_id_array(query[:key])
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
              find_by_sql_without_kasket(*args)
            elsif value.is_a?(Array)
              filter_pending_records(find_by_sql_with_kasket_on_id_array(value))
            else
              filter_pending_records(Array.wrap(value).collect { |record| instantiate(record.dup) })
            end

            payload = {
              record_count: result_set.length,
              class_name: to_s
            }

            ActiveSupport::Notifications.instrument('instantiation.active_record', payload) { result_set }
          else
            store_in_kasket(query[:key], find_by_sql_without_kasket(*args))
          end
        end
      else
        find_by_sql_without_kasket(*args)
      end
    end

    def find_by_sql_with_kasket_on_id_array(keys)
      begin
        key_attributes_map = Kasket.cache.read_multi(*keys)
      rescue RuntimeError => e
        # Elasticache Memcached has a bug where it returns a 0x00 binary protocol response with no data
        # during a reboot, causing the Dalli memcached client to throw a RuntimeError during a multi get
        # (https://github.com/petergoldstein/dalli/blob/v2.7.7/lib/dalli/server.rb#L148).
        # Fall back to the database when this happens.
        if e.message == "multi_response has completed"
          key_attributes_map = missing_records_from_db(keys)
        else
          raise
        end
      else
        found_keys, missing_keys = keys.partition {|k| key_attributes_map[k] }
        found_keys.each {|k| key_attributes_map[k] = instantiate(key_attributes_map[k].dup) }
        key_attributes_map.merge!(missing_records_from_db(missing_keys))
      end

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
