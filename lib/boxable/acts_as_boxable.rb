module Boxable
  module ActsAsBoxable
    class Helper
      # @abstract Known whether an ActiveRecord association is an has_... or not
      # @param [ActiveRecord <Reflection>] a - association to test
      # @return Bool
      def self.association_foreign?(a)
        a.class.name.demodulize.in?(%w[HasOneReflection HasManyReflection])
      end

      def self.association_name_class(klass, name)
        asso = klass.reflect_on_all_associations.select{ |a| a.name == name.to_sym }
        asso ? asso.klass : nil
      end

      # @abstract Known whether an ActiveRecord association is marked as boxable or not
      # @param [ActiveRecord <Reflection>] a - association to test
      # @return Bool
      def self.association_boxable?(a, base_class)
        if association_foreign?(a)
          begin
            a.klass.respond_to? :boxable_config
            conf = a.klass.boxable_config
            conf.parent ? true : false
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
        klass.reflect_on_all_associations.select{ |a| association_boxable?(a, klass) }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_boxable(options = {})
        class_eval do
          # @abstract Get metadata about the class Box parent
          # @return Hash
          def self.box_parent_meta
            parent_association = reflect_on_all_associations.select{ |a| a.name == boxable_config.parent }.first
            unless parent_association
              raise Boxable::Error.new("Parent association '#{boxable_config.parent}' not found for class #{name}")
            end

            associated_name = parent_association.options[:inverse_of]
            unless associated_name
              raise Boxable::Error.new("No option 'inverse_of' defined on association '#{parent_association.name}' for class #{name}")
            end
            begin
              unless parent_association.klass.respond_to? :boxable_config
                raise Boxable::Error.new("Box parent class '#{parent_association.klass}' is not boxable")
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
            raise Boxable::Error.new("Cannot resolve folder '#{folder_id_key}' in ENV") unless folder_id

            folder_id
          end

          # Store boxable metadata in the instance
          cattr_accessor :boxable_config
          self.boxable_config = Boxable::BoxableConfig.new(options)

          # Define a slug based on full_name, used for Box folder name
          extend FriendlyId
          friendly_id :full_name, use: :slugged

          # Record folders
          has_many :box_folders, as: :boxable, dependent: :destroy
          has_many :box_files, as: :boxable, dependent: :destroy
          has_many :box_file_collections, as: :boxable, dependent: :destroy
          prepend InstanceMethods
        end

        begin
          # Ensure model is correct on initialization, by calling critical methods
          if boxable_config.parent
            # Try getting class parent folder metadata, if any
            box_parent_meta
          else
            # Try getting class folder in Box root, otherwise
            box_folder_id_in_root
          end
        rescue Boxable::Error => e
          puts "BOXABLE WARNING: #{e}"
        end

        class_eval do
          # Build all Box folders right before object creation
          before_create do |o|
            box_folders.build
            Boxable::ActsAsBoxable::Helper.boxable_associations(o.class).each do |a|
              box_folders.build(attribute_name: a.name)
            end
          end

          prepend InstanceMethods
        end
      end

      def has_one_box_file(basename)
        raise Boxable::Error.new("File attached with name '#{name}' to class '#{self.name}' not marked as boxable.\n" \
                                 "Use 'acts_as_boxable' in that class declaration to set a folder in which the file will be placed.") unless respond_to?(:boxable_config)
        class_eval do
          define_method(basename) do
            res = box_files.find_by(basename: basename)
            raise Boxable::Error.new("No BoxFile record for '#{basename}' of class '#{self.class.name}'") unless res

            res
          end

          before_create do
            box_files.build(basename: basename)
          end
        end
      end

      def has_many_box_files(basename)
        raise Boxable::Error.new("File attached with name '#{name}' to class '#{self.name}' not marked as boxable.\n" \
                                 "Use 'acts_as_boxable' in that class declaration to set a folder in which the file will be placed.") unless respond_to?(:boxable_config)
        class_eval do
          define_method(basename) do
            res = box_file_collections.find_by(basename: basename)
            raise Boxable::Error.new("No BoxFile record for '#{basename}' of class '#{self.class.name}'") unless res

            res
          end

          before_create do
            box_file_collections.build(basename: basename)
          end
        end
      end

      module InstanceMethods
        # @abstract Get the BoxFolder for the object (attribute_name = nil), or an attribute
        # @option [Symbol] attribute_name - Name of the attribute
        # @return String
        def box_folder_instance(attribute_name = nil)
          res = box_folders.find_by(attribute_name: attribute_name)
          raise Boxable::Error.new("No Box folder for #{attribute_name && "attribute '#{attribute_name}' of '"} class '#{self.class.name}") unless res
          res
        end

        # @abstract Get the box folder id for the object (attribute_name = nil), or an attribute
        # @option [Symbol] attribute_name - Name of the attribute
        # @return String
        def box_folder(attribute_name = nil)
          box_folder_instance(attribute_name).folder
        end

        # @abstract Get the parent of the box folder for the object (attribute_name = nil), or an attribute
        # @option [Symbol] attribute_name - Name of the attribute
        # @return String
        def box_parent_folder(attribute_name = nil)
          box_folder_instance(attribute_name).parent
        end

        # @abstract Get parent folder id for objects and attribute
        # @param [Symbol] parent_name - Method to call to get parent folder (in case of attribute)
        # @note Set above parameter to nil if object folder
        # @note That method differs from above by the fact it can be used by an object without BoxFolder associated (used on initialization)
        # @return String
        def boxable_parent_id(attribute_name)
          # Check whether we have an object or attribute folder
          if attribute_name
            # Attribute folder, parent is object associated
            box_folder
          else
            # Object folder, check whether the class has a parent or not
            if self.class.boxable_config.parent
              # Get parent folder id
              meta = self.class.box_parent_meta
              send(meta[:parent_method]).box_folder(meta[:parent_association])
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

ActiveRecord::Base.send :include, Boxable::ActsAsBoxable