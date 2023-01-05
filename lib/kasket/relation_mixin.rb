# frozen_string_literal: true
module Kasket
  module RelationMixin
    def to_kasket_query
      if arel.is_a?(Arel::SelectManager)
        if ActiveRecord::VERSION::STRING < '5.2'
          arel.to_kasket_query(klass, (@values[:where].to_h.values + Array(@values[:limit])))
        else
          arel.to_kasket_query(klass)
        end
      end
    rescue TypeError # unsupported object in ast
      nil
    end
  end
end
