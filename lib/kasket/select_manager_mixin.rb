module Kasket
  module SelectManagerMixin
    def to_kasket_query(klass, binds = [])
      begin
        query = Kasket::Visitor.new(klass, binds).accept(ast)
      rescue TypeError # unsupported object in ast
        return nil
      end

      return nil if query.nil? || query == :unsupported
      return nil if query[:attributes].blank?
      return nil if query[:limit] > 1 if query[:limit]

      query[:index] = query[:attributes].map(&:first)
      if query[:index].size > 1
        attributes = query[:attributes]
        attributes.each do |attribute_and_value|
          value = attribute_and_value[1]
          if value.is_a?(Array)
            return nil if value.size != 1
            attribute_and_value[1] = value.first
          end
        end
      end

      query[:key] = klass.kasket_key_for(query[:attributes])
      query[:key] << '/first' if query[:limit] == 1 && !query[:index].include?(:id)

      query
    end
  end
end
