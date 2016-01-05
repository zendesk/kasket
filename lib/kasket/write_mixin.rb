module Kasket
  module WriteMixin

    module ClassMethods
      def remove_from_kasket(ids)
        Array(ids).each do |id|
          Kasket.cache.delete(kasket_key_for_id(id))
        end
      end

      def update_counters_with_kasket_clearing(*args)
        remove_from_kasket(args[0])
        update_counters_without_kasket_clearing(*args)
      end

      def transaction_with_kasket_disabled(*args)
        without_kasket do
          transaction_without_kasket_disabled(*args) { yield }
        end
      end
    end

    module InstanceMethods
      def kasket_key
        @kasket_key ||= new_record? ? nil : self.class.kasket_key_for_id(id)
      end

      def default_kasket_cacheable?
        true
      end

      def store_in_kasket(key = kasket_key)
        if kasket_cacheable? && key
          options = { expires_in: self.class.kasket_ttl } if self.class.kasket_ttl
          Kasket.cache.write(key, attributes_before_type_cast.dup, options)
          key
        end
      end

      def kasket_keys
        attribute_sets = [attributes.symbolize_keys]

        if previous_changes.present?
          old_attributes = Hash[*previous_changes.map {|attribute, values| [attribute, values[0]]}.flatten].symbolize_keys
          attribute_sets << old_attributes.reverse_merge(attribute_sets[0])
        end

        keys = []
        self.class.kasket_indices.each do |index|
          keys += attribute_sets.map do |attribute_set|
            key = self.class.kasket_key_for(index.map { |attribute| [attribute, attribute_set[attribute]]})
            index.include?(:id) ? key : [key, key + '/first']
          end
        end

        keys.flatten!
        keys.uniq!
        keys
      end

      def kasket_after_commit
        keys = kasket_keys

        if persisted? && Kasket::CONFIGURATION[:write_through]
          key = store_in_kasket
          keys.delete(key)
        end

        keys.each do |key|
          Kasket.cache.delete(key)
        end
      end

      def clear_kasket_indices
        kasket_keys.each do |key|
          Kasket.cache.delete(key)
        end
      end

      def reload(*args)
        clear_kasket_indices
        super
      end

      def update_column(*args)
        result = super
        clear_kasket_indices
        result
      end

      def kasket_after_commit_dummy
        # This is here to force committed! to be invoked.
      end

      def kasket_after_save
        Kasket.add_pending_record(self, self)
      end

      def kasket_after_destroy
        Kasket.add_pending_record(self, nil)
      end

      def committed!(*)
        Kasket.clear_pending_records
        kasket_after_commit if persisted? || destroyed?
        super
      end

      def rolledback!(*)
        Kasket.clear_pending_records
        super
      end
    end

    def self.included(model_class)
      model_class.extend         ClassMethods
      model_class.send :include, InstanceMethods

      unless model_class.method_defined?(:kasket_cacheable?)
        model_class.send(:alias_method, :kasket_cacheable?, :default_kasket_cacheable?)
      end

      model_class.after_save :kasket_after_save
      model_class.after_destroy :kasket_after_destroy
      model_class.after_commit :kasket_after_commit_dummy

      if ActiveRecord::VERSION::MAJOR == 3 || (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR == 0)
        model_class.after_touch :kasket_after_commit
      end

      class << model_class
        alias_method_chain :transaction, :kasket_disabled
        alias_method_chain :update_counters, :kasket_clearing
      end
    end
  end
end
