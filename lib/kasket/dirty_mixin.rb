module Kasket
  module DirtyMixin
    def kasket_dirty_methods(*method_names)
      method_names.each do |method|
        without = "without_kasket_update_#{method}"
        return if method_defined? without

        alias_method without, method
        define_method method do |*args, &block|
          result = send(without, *args, &block)
          clear_kasket_indices
          result
        end
      end
    end

    alias_method :kasket_dirty_method, :kasket_dirty_methods
  end
end
