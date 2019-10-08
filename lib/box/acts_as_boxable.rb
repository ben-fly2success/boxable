module Box
  module ActsAsBoxable
    class Helper
      # @abstract Known whether an ActiveRecord association is an has_... or not
      # @param [ActiveRecord <Reflection>] a - association to test
      # @return Bool
      def self.association_foreign?(a)
        a.class.name.demodulize.in?(%w[HasOneReflection HasManyReflection])
      end

      # @abstract Known whether an ActiveRecord association is marked as boxable or not
      # @param [ActiveRecord <Reflection>] a - association to test
      # @return Bool
      def self.association_boxable?(a)
        if association_foreign?(a)
          begin
            a.klass.respond_to? :boxable_config
          rescue NameError # Some associated class might not be resolvable
            false
          end
        else
          false
        end
      end

      # @abstract Get all associations stored in Box for a class
      # @param <ActiveRecord> klass - Class to test
      # @return Bool
      def self.boxable_associations(klass)
        klass.reflect_on_all_associations.select{ |a| association_boxable?(a) }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_boxable(options = {})
        class_eval do
          cattr_accessor :boxable_config
          self.boxable_config = Box::BoxableConfig.new(options) # Store boxable metadata in the instance

          # Define a slug based on full_name, used for box folder name
          extend FriendlyId
          friendly_id :full_name, use: :slugged

          # Record folder
          has_one :box_folder, as: :boxable, dependent: :destroy
        end

        # Setup associations box folders as has_one
        Box::ActsAsBoxable::Helper.boxable_associations(self).each do |a|
          box_folder_name = "box_#{a.name}_folder".to_sym
          class_eval do
            has_one box_folder_name, as: :boxable, class_name: 'BoxFolder', dependent: :destroy
          end
        end

        class_eval do
          # Build all box folders right before object creation
          before_create do |o|
            o.build_box_folder unless o.box_folder
            Box::ActsAsBoxable::Helper.boxable_associations(o.class).each do |a|
              box_folder_name = "box_#{a.name}_folder".to_sym
              o.send("build_#{box_folder_name}", parent: :box_folder, name: a.name)
            end
          end

          prepend InstanceMethods
        end
      end

      module InstanceMethods
      end
    end
  end
end

ActiveRecord::Base.send :include, Box::ActsAsBoxable