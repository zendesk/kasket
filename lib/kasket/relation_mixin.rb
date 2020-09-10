# frozen_string_literal: true
module Kasket
  module RelationMixin
    # binds can be removed when support for Rails < 5 is removed
    def to_kasket_query(binds = nil)
      if arel.is_a?(Arel::SelectManager)
        if ActiveRecord::VERSION::MAJOR < 5
          arel.to_kasket_query(klass, (binds || bind_values))
        elsif ActiveRecord::VERSION::STRING < '5.2'
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
