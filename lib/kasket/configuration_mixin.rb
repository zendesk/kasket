require 'active_support'
require "digest/md5"

module Kasket

  module ConfigurationMixin

    def without_kasket(&block)
      old_value = Thread.current[:kasket_disabled] || false
      Thread.current[:kasket_disabled] = true
      yield
    ensure
      Thread.current[:kasket_disabled] = old_value
    end

    def use_kasket?
      !Thread.current[:kasket_disabled]
    end

    def kasket_parser
      @kasket_parser ||= QueryParser.new(self)
    end

    def kasket_key_prefix
      @kasket_key_prefix ||= "kasket-#{Kasket::Version::PROTOCOL}/#{kasket_activerecord_version}/#{table_name}/version=#{column_names.join.sum}/"
    end

    def kasket_activerecord_version
      "R#{ActiveRecord::VERSION::MAJOR}#{ActiveRecord::VERSION::MINOR}"
    end

    def kasket_key_for(attribute_value_pairs)
      if attribute_value_pairs.size == 1 && attribute_value_pairs[0][0] == :id && attribute_value_pairs[0][1].is_a?(Array)
        attribute_value_pairs[0][1].map {|id| kasket_key_for_id(id)}
      else
        key = attribute_value_pairs.map do |attribute, value|
          column = columns_hash[attribute.to_s]
          value = nil if value.blank?
          attribute.to_s << '=' << quoted_value_for_column(value, column)
        end.join('/')

        if key.size > (250 - kasket_key_prefix.size) || key =~ /\s/
          key = Digest::MD5.hexdigest(key)
        end

        kasket_key_prefix + key
      end
    end

    def kasket_key_for_id(id)
      kasket_key_for([['id', id]])
    end

    def kasket_indices
      result = if defined?(@kasket_indices) && @kasket_indices
        @kasket_indices
      else
        []
      end
      result += superclass.kasket_indices unless self == ActiveRecord::Base
      result.uniq
    end

    def has_kasket_index_on?(sorted_attributes)
      kasket_indices.include?(sorted_attributes)
    end

    def has_kasket(options = {})
      has_kasket_on :id
    end

    def has_kasket_on(*args)
      attributes = args.sort_by!(&:to_s)
      if attributes != [:id] && !has_kasket_index_on?([:id])
        has_kasket_on(:id)
      end

      @kasket_indices ||= []
      @kasket_indices << attributes unless @kasket_indices.include?(attributes)

      include WriteMixin unless include?(WriteMixin)
      extend DirtyMixin unless respond_to?(:kasket_dirty_methods)
      extend ReadMixin unless methods.map(&:to_sym).include?(:find_by_sql_with_kasket)
    end

    def kasket_expires_in(time)
      @kasket_ttl = time
    end

    attr_reader :kasket_ttl

    private

    def quoted_value_for_column(value, column)
      if column
        casted_value = case
        when connection.respond_to?(:type_cast_from_column)
          connection.type_cast_from_column(column, value)
        when column.respond_to?(:type_cast_for_database)
          column.type_cast_for_database(value) # Rails 4.2
        else
          column.type_cast(value)
        end
        connection.quote(casted_value).downcase
      else
        value.to_s
      end
    end
  end
end
