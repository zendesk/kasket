# frozen_string_literal: true
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

    private

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
      return :unsupported if ordered?(node)
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
      return :unsupported if ActiveRecord::VERSION::MAJOR < 5 ? node.having : node.havings.present?
      return :unsupported if node.set_quantifier
      return :unsupported if !node.source || node.source.empty?
      return :unsupported if node.projections.size != 1

      select = node.projections[0]
      select = select.name if select.respond_to?(:name)
      return :unsupported if select != '*'

      parts = [visit(node.source)]

      parts += node.wheres.map {|where| visit(where) }

      parts.include?(:unsupported) ? :unsupported : parts
    end

    def visit_Arel_Nodes_Limit(node, *_)
      if ActiveRecord::VERSION::MAJOR < 5
        { limit: node.value.to_i }
      else
        { limit: visit(node.value).to_i }
      end
    end

    def visit_Arel_Nodes_JoinSource(node, *_)
      return :unsupported if !node.left || node.right.any?
      return :unsupported unless node.left.is_a?(Arel::Table)
      visit(node.left)
    end

    def visit_Arel_Table(node, *_)
      { from: node.name }
    end

    def visit_Arel_Nodes_And(node, *_)
      attributes = node.children.map { |child| visit(child) }
      return :unsupported if attributes.include?(:unsupported)
      attributes.sort! { |pair1, pair2| pair1[0].to_s <=> pair2[0].to_s }
      { attributes: attributes }
    end

    def visit_Arel_Nodes_In(node, *_)
      left = visit(node.left)
      return :unsupported if left != :id

      [left, visit(node.right)]
    end

    def visit_Arel_Nodes_Equality(node, *_)
      right =
        case node.right
        when false then 0 # This should probably be removed when Rails 3.2 is not supported anymore
        when nil   then nil
        else visit(node.right)
        end
      [visit(node.left), right]
    end

    def visit_Arel_Attributes_Attribute(node, *_)
      self.last_column = column_for(node.name)
      node.name.to_sym
    end

    def literal(node, *_)
      if node == '?'
        @binds.shift.last.to_s
      else
        node.to_s
      end
    end

    def visit_Arel_Nodes_BindParam(_x, *_)
      if ActiveRecord::VERSION::MAJOR < 5
        visit(@binds.shift[1])
      else
        visit(@binds.shift)
      end
    end

    def visit_Array(node, *_)
      node.map {|value| visit(value) }
    end

    def visit_Arel_Nodes_Casted(node, *_)
      case node.val
      when nil    then nil
      when String then node.val
      else quoted(node.val)
      end
    end

    def visit_TrueClass(_node)
      1
    end

    def visit_FalseClass(_node)
      0
    end

    def quoted(node)
      @model_class.connection.quote(node)
    end

    # any non `id asc` ordering
    def ordered?(node)
      !node.orders.all? { |o| o.is_a?(Arel::Nodes::Ascending) && o.expr.name == "id" }
    end

    alias_method :visit_String, :literal
    alias_method :visit_Fixnum, :literal
    alias_method :visit_Integer, :literal
    alias_method :visit_Bignum, :literal
    alias_method :visit_Arel_Nodes_SqlLiteral, :literal
  end
end
