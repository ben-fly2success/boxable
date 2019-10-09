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
      def has_one_box_folder(name, attribute_name: nil)
        class_eval do
          define_method(name) do
            BoxFolder.find_by(boxable: self, attribute_name: attribute_name)
          end
        end
      end

      def acts_as_boxable(options = {})
        class_eval do
          # @abstract Get metadata about the class Box parent
          # @return Hash
          def self.box_parent_meta
            parent_association = reflect_on_all_associations.select{ |a| a.name == boxable_config.parent }.first
            unless parent_association
              raise "Parent association '#{boxable_config.parent}' not found for class #{name}"
            end

            associated_name = parent_association.options[:inverse_of]
            unless associated_name
              raise "No option 'inverse_of' defined on association '#{parent_association.name}' for class #{name}"
            end
            begin
              unless parent_association.klass.respond_to? :boxable_config
                raise "Box parent class '#{parent_association.klass}' is not boxable"
              end
            rescue ArgumentError # Rescue polymorphic associations
            end

            {parent_method: parent_association.name, parent_association: associated_name}
          end

          # @abstract Get class folder id in Box root
          # @return Hash
          def self.box_folder_id_in_root
            folder_id_key = "BOX_#{self.table_name.upcase}_FOLDER"
            folder_id = ENV[folder_id_key]
            raise "Cannot resolve folder '#{folder_id_key}' in ENV" unless folder_id

            folder_id
          end

          # Store boxable metadata in the instance
          cattr_accessor :boxable_config
          self.boxable_config = Box::BoxableConfig.new(options)

          # Define a slug based on full_name, used for Box folder name
          extend FriendlyId
          friendly_id :full_name, use: :slugged

          # Record folder
          has_one_box_folder :box_folder
          has_many :box_folders, as: :boxable, class_name: 'BoxFolder', dependent: :destroy
          prepend InstanceMethods
        end

        unless ENV['BOXABLE_NOCHECK'] # Set on installation
          # Ensure model is correct on initialization, by calling critical methods
          if boxable_config.parent
            # Try getting class parent folder metadata, if any
            box_parent_meta
          else
            # Try getting class folder in Box root, otherwise
            box_folder_id_in_root
          end
        end

        # Setup associations Box folders as has_one
        Box::ActsAsBoxable::Helper.boxable_associations(self).each do |a|
          box_folder_name = "box_#{a.name}_folder".to_sym
          class_eval do
            has_one box_folder_name, as: :boxable, class_name: 'BoxFolder', dependent: :destroy
          end
        end

        class_eval do
          # Build all Box folders right before object creation
          before_create do |o|
            box_folders.build
            Box::ActsAsBoxable::Helper.boxable_associations(o.class).each do |a|
              box_folders.build(attribute_name: a.name)
            end
          end

          def box_folder(attribute_name = nil)
            box_folders.find_by(attribute_name: attribute_name)
          end

          prepend InstanceMethods
        end
      end

      module InstanceMethods
        # @abstract Get parent folder id for objects and attribute
        # @param [Symbol] parent_name - Method to call to get parent folder (in case of attribute)
        # @note Set above parameter to nil if object folder
        # @return String
        def box_parent_id(attribute_name)
          # Check whether we have an object or attribute folder
          if attribute_name
            # Attribute folder, parent is object associated
            send(:box_folder).folder
          else
            # Object folder, check whether the class has a parent or not
            if self.class.boxable_config.parent
              # Get parent folder id
              meta = self.class.box_parent_meta
              parent_folder = send(meta[:parent_method]).box_folder(meta[:parent_association])
              parent_folder.folder
            else
              # Class has no parent, get folder in box root
              self.class.box_folder_id_in_root
            end
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Box::ActsAsBoxable