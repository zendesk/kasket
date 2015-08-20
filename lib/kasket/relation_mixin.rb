module Kasket
  module RelationMixin
    def to_kasket_query(binds = nil)
      if arel.is_a?(Arel::SelectManager)
        arel.to_kasket_query(klass, (binds || bind_values))
      end
    rescue TypeError # unsupported object in ast
      return nil
    end
  end
end
