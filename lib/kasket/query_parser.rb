# frozen_string_literal: true
module Kasket
  class QueryParser
    # Examples:
    # SELECT * FROM `users` WHERE (`users`.`id` = 2)
    # SELECT * FROM `users` WHERE (`users`.`id` = 2) LIMIT 1
    # 'SELECT * FROM \'posts\' WHERE (\'posts\'.\'id\' = 574019247) '

    AND = /\s+AND\s+/i.freeze
    VALUE = /'?(\d+|\?|(?:(?:[^']|''|\\')*))'?/.freeze # Matches: 123, ?, '123', '12''3'

    def initialize(model_class)
      @model_class = model_class

      @supported_query_pattern = /^select\s+(.+?)\s+from (?:`|")#{@model_class.table_name}(?:`|") where (.*?)(|\s+limit 1)\s*$/i

      @star_pattern = /^((`|")#{@model_class.table_name}\2\.)?\*$/
      # Matches: `users`.id, `users`.`id`, users.id, id
      @table_and_column_pattern = /(?:(?:`|")?#{@model_class.table_name}(?:`|")?\.)?(?:`|")?([a-zA-Z]\w*)(?:`|")?/
      # Matches: KEY = VALUE, (KEY = VALUE), ()(KEY = VALUE))
      @key_eq_value_pattern = /^[\(\s]*#{@table_and_column_pattern}\s+(=|IN)\s+#{VALUE}[\)\s]*$/
    end

    ##
    # Parses a SQL query to produce a kasket query
    #
    # @param sql [String] the sql query to parse
    # @return [Hash|nil] the kasket query, or nil if the sql query is not supported
    def parse(sql)
      if match = @supported_query_pattern.match(sql)
        select = match[1]
        unless @star_pattern.match? select
          # If we're not selecting all columns using star, then ensure all columns are selected explicitly
          select_columns = select.split(/\s*,\s*/).map do |s|
            break unless column_match = @table_and_column_pattern.match(s)

            column_match[1]
          end.uniq
          columns = @model_class.column_names
          return unless columns.size == select_columns.size && (columns - select_columns).empty?
        end
        where = match[2]
        limit = match[3]

        query = {}
        query[:attributes] = sorted_attribute_value_pairs(where)
        return if query[:attributes].nil?

        if query[:attributes].size > 1 && query[:attributes].map(&:last).any?(Array)
          # this is a query with IN conditions AND other conditions
          return
        end

        query[:index] = query[:attributes].map(&:first)
        query[:limit] = limit.blank? ? nil : 1
        query[:key] = @model_class.kasket_key_for(query[:attributes])
        query[:key] << '/first' if query[:limit] == 1 && !query[:index].include?(:id)
        query
      end
    end

    private

    def sorted_attribute_value_pairs(conditions)
      if attributes = parse_condition(conditions)
        attributes.sort { |pair1, pair2| pair1[0].to_s <=> pair2[0].to_s }
      end
    end

    def parse_condition(conditions = '', *values)
      values = values.dup
      conditions.split(AND).inject([]) do |pairs, condition|
        matched, column_name, operator, sql_value = *@key_eq_value_pattern.match(condition)
        if matched
          if operator == 'IN'
            if column_name == 'id'
              values = sql_value[1..-2].split(',').map(&:strip)
              pairs << [column_name.to_sym, values]
            else
              return nil
            end
          else
            value = sql_value == '?' ? values.shift : sql_value
            pairs << [column_name.to_sym, value.gsub(/''|\\'/, "'")]
          end
        else
          return nil
        end
      end
    end
  end
end
