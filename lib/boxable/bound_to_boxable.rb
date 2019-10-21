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
    end
  end
end

ActiveRecord::Base.send :include, Boxable::BoundToBoxable