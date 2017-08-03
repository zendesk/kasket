# frozen_string_literal: true
module Kasket
  module RelationMixin
    def to_kasket_query(binds = nil)
      if arel.is_a?(Arel::SelectManager)
        if ActiveRecord::VERSION::MAJOR < 5
          arel.to_kasket_query(klass, (binds || bind_values))
        else
          arel.to_kasket_query(klass, (@values[:where].binds.map(&:value_for_database) + Array(@values[:limit])))
        end
      end
    rescue TypeError # unsupported object in ast
      return nil
    end
  end
end
