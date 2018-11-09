# frozen_string_literal: true
module Kasket
  module ReadMixin
    include Kasket::Instrumentation

    def self.extended(base)
      class << base
        alias_method :find_by_sql_without_kasket, :find_by_sql
        alias_method :find_by_sql, :find_by_sql_with_kasket
      end
    end

    def find_by_sql_with_kasket(*args)
      sql = args[0]

      if use_kasket?
        query = if sql.respond_to?(:to_kasket_query)
          if ActiveRecord::VERSION::MAJOR < 5
            sql.to_kasket_query(self, args[1])
          else
            sql.to_kasket_query(self, args[1].map(&:value_for_database))
          end
        else
          kasket_parser.parse(sanitize_sql(sql))
        end
      end

      if query && has_kasket_index_on?(query[:index])
        if query[:key].is_a?(Array)
          find_by_sql_with_kasket_on_id_array(query[:key])
        else
          if value = instrument('cache.read') { Kasket.cache.read(query[:key]) }
            if value.is_a?(Array)
              filter_pending_records(find_by_sql_with_kasket_on_id_array(value))
            else
              filter_pending_records(Array.wrap(value).collect { |record| instantiate(record.dup) })
            end
          else
            store_in_kasket(query[:key], find_by_sql_without_kasket(*args))
          end
        end
      else
        find_by_sql_without_kasket(*args)
      end
    end

    def find_by_sql_with_kasket_on_id_array(keys)
      key_attributes_map = instrument('cache.read_multi') { Kasket.cache.read_multi(*keys) }

      found_keys, missing_keys = keys.partition {|k| key_attributes_map[k] }
      found_keys.each {|k| key_attributes_map[k] = instantiate(key_attributes_map[k].dup) }
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
        ActiveRecord::Base.logger.info("[KASKET] would have stored an empty resultset") if ActiveRecord::Base.logger
      elsif records.size <= Kasket::CONFIGURATION[:max_collection_size]
        if records.all?(&:kasket_cacheable?)
          instance_keys = records.map(&:store_in_kasket)
          instrument('cache.write') { Kasket.cache.write(key, instance_keys) }
        end
      end
      records
    end
  end
end
