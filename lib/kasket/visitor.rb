require 'arel'

module Kasket
  class Visitor < Arel::Visitors::Visitor
    def initialize(model_class, binds)
      @model_class = model_class
      @binds       = binds.dup
      super()
    end

    def accept(node)
      self.last_column = nil
      super
    end

    def last_column=(col)
      Thread.current[:arel_visitors_to_sql_last_column] = col
    end

    def last_column
      Thread.current[:arel_visitors_to_sql_last_column]
    end

    def column_for(name)
      @model_class.columns_hash[name.to_s]
    end

    def visit_Arel_Nodes_SelectStatement(node, *_)
      return :unsupported if node.with
      return :unsupported if node.offset
      return :unsupported if node.lock
      return :unsupported if !default_sql_order?(node)
      return :unsupported if node.cores.size != 1

      query = visit_Arel_Nodes_SelectCore(node.cores[0])
      return query if query == :unsupported

      query = query.inject({}) do |memo, item|
        memo.merge(item)
      end

      query.merge!(visit(node.limit)) if node.limit
      query
    end

    def visit_Arel_Nodes_SelectCore(node, *_)
      return :unsupported if node.groups.any?
      return :unsupported if node.having
      return :unsupported if node.set_quantifier
      return :unsupported if (!node.source || node.source.empty?)
      return :unsupported if node.projections.size != 1

      select = node.projections[0]
      select = select.name if select.respond_to?(:name)
      return :unsupported if select != '*'

      parts = [visit(node.source)]

      parts += node.wheres.map {|where| visit(where) }

      parts.include?(:unsupported) ? :unsupported : parts
    end

    def visit_Arel_Nodes_Limit(node, *_)
      {:limit => node.value.to_i}
    end

    def visit_Arel_Nodes_JoinSource(node, *_)
      return :unsupported if !node.left || node.right.any?
      return :unsupported if !node.left.is_a?(Arel::Table)
      visit(node.left)
    end

    def visit_Arel_Table(node, *_)
      {:from => node.name}
    end

    def visit_Arel_Nodes_And(node, *_)
      attributes = node.children.map { |child| visit(child) }
      return :unsupported if attributes.include?(:unsupported)
      attributes.sort! { |pair1, pair2| pair1[0].to_s <=> pair2[0].to_s }
      { :attributes => attributes }
    end

    def visit_Arel_Nodes_In(node, *_)
      left = visit(node.left)
      return :unsupported if left != :id

      [left, visit(node.right)]
    end

    def visit_Arel_Nodes_Equality(node, *_)
      right = node.right
      [visit(node.left), right ? visit(right) : nil]
    end

    def visit_Arel_Attributes_Attribute(node, *_)
      self.last_column = column_for(node.name)
      node.name.to_sym
    end

    def literal(node, *_)
      if node == '?'
        column, value = @binds.shift
        value.to_s
      else
        node.to_s
      end
    end

    def visit_Arel_Nodes_BindParam(x, *_)
      visit(@binds.shift[1])
    end

    def visit_Array(node, *_)
      node.map {|value| visit(value) }
    end

    def visit_Arel_Nodes_Casted(node, *_)
      quoted(node.val)
    end

    #TODO: We are actually not using this?
    def quoted(node)
      @model_class.connection.quote(node, self.last_column)
    end

    private

    def default_sql_order?(node)
      return true if node.orders.empty?
      return false if node.orders.size > 1

      # check if the given order is the default `table.id ASC` order
      default = "`#{@model_class.table_name}`.`#{@model_class.primary_key}` ASC"
      given = (node.orders.first.respond_to?(:to_sql) ? node.orders.first.to_sql : node.orders.first.to_s)
      given == default
    end

    alias :visit_String                :literal
    alias :visit_Fixnum                :literal
    alias :visit_TrueClass             :literal
    alias :visit_FalseClass            :literal
    alias :visit_Arel_Nodes_SqlLiteral :literal
  end
end
