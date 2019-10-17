module Boxable
  module BoundToBoxable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def bound_to_boxable
        class_eval do
          belongs_to :boxable, polymorphic: true, optional: true
          prepend InstanceMethods
        end
      end
    end

    module InstanceMethods
      # @abstract Get name used for Box file
      # @return String
      def name_from_boxable
        if name_method
          boxable.send(name_method)
        else
          name
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Boxable::BoundToBoxable