module Kasket
  module WriteMixin

    module ClassMethods
      def remove_from_kasket(ids)
        Array(ids).each do |id|
          Rails.cache.delete(kasket_key_for_id(id))
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

      def store_in_kasket
        if !readonly? && kasket_key
          Rails.cache.write(kasket_key, @attributes.dup)
        end
      end

      def kasket_keys
        attribute_sets = [attributes.symbolize_keys]

        if changed?
          old_attributes = Hash[*changes.map {|attribute, values| [attribute, values[0]]}.flatten].symbolize_keys
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

      def clear_kasket_indices
        kasket_keys.each do |key|
          Rails.cache.delete(key)
        end
      end

      def reload_with_kasket_clearing(*args)
        Kasket.clear_local
        reload_without_kasket_clearing(*args)
      end
    end

    def self.included(model_class)
      model_class.extend         ClassMethods
      model_class.send :include, InstanceMethods

      model_class.after_save :clear_kasket_indices
      model_class.after_destroy :clear_kasket_indices

      model_class.alias_method_chain :reload, :kasket_clearing
   

      class << model_class
        alias_method_chain :transaction, :kasket_disabled
        alias_method_chain :update_counters, :kasket_clearing
      end
    end
  end
end
