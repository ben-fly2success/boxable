module Boxable
  module ActsAsBoxable
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

          # Store boxable metadata in the instance
          cattr_accessor :boxable_config
          self.boxable_config = Boxable::BoxableConfig.new(options)

          # Record folders
          has_many :box_files, as: :boxable, dependent: :destroy
          has_one :bound_box_folder, class_name: 'BoxFolder', as: :boxable
          after_destroy do
            # Make sure root is actually destroyed after everything else
            bound_box_folder&.destroy
          end
          prepend InstanceMethods
        end

        valid_folder_modes = %i[parent common unique]
        unless self.boxable_config.folder.in?(valid_folder_modes)
          raise "Unknown Boxable folder mode '#{self.boxable_config.folder}' for class '#{self.name}'.\nValid modes are #{valid_folder_modes}"
        end

        begin
          # Ensure model is correct on initialization, by calling critical methods
          if boxable_config.parent
            # Try getting class parent folder metadata, if any
            box_parent_meta
          end
        rescue Boxable::Error => e
          puts "BOXABLE WARNING: #{e}"
        end

        class_eval do
          after_create do
            after_create_box_attachments.each do |t|
              t.perform_for self
            end
          end
        end
      end

      def has_one_box_file(name, name_method: nil, generate_url: false)
        class_eval do
          define_method(name) do
            box_folder_root.file(name, self)
          end

          define_method "#{name}=" do |value|
            Boxable::AttachmentTask.schedule_for(self, :one_file, name, name_method && send(name_method), value, generate_url: generate_url)
          end
        end
      end

      def has_one_box_folder(name)
        class_eval do
          define_method(name) do
            box_folder_root.sub(name)
          end
        end
      end

      def has_one_box_picture(name, generate_url: true)
        class_eval do
          define_method "#{name}=" do |value|
            Boxable::AttachmentTask.schedule_for(self, :one_picture, name, nil, value, generate_url: generate_url)
          end

          define_method name do
            box_folder_root.sub(name).file('original', self)
          end
        end
      end

      module InstanceMethods
        def after_create_box_attachments
          @after_create_box_attachments_impl ||= []
        end

        def box_folder_root_parent
          if boxable_config.parent
            meta = self.class.box_parent_meta
            send(meta[:parent_method]).box_folder(meta[:parent_association])
          else
            BoxFolder.root.sub(self.class.table_name)
          end
        end

        def box_folder_root
          case self.class.boxable_config.folder
          when :parent # Boxable folder is parent folder
            send(self.class.boxable_config.parent).box_folder_root
          when :common # Boxable folder is dedicated folder of the association in the parent
            box_folder_root_parent
          when :unique # Boxable folder is unique to this record, and is located in a sub folder of the parent (default mode)
            bound_box_folder || send("#{new_record? ? 'build' : 'create'}_bound_box_folder",
                                     name: send(self.class.boxable_config.name),
                                     parent: box_folder_root_parent)
          else
            raise "Unknown Boxable folder mode '#{self.class.boxable_config.folder}'"
          end
        end

        # @abstract Get the BoxFolder for the object (attribute_name = nil), or an attribute
        # @option [Symbol] attribute_name - Name of the attribute
        # @return String
        def box_folder(attribute_name = nil)
          root = box_folder_root
          attribute_name ? root.sub(attribute_name) : root
        end

        # @abstract Get the box folder id for the object (attribute_name = nil), or an attribute
        # @option [Symbol] attribute_name - Name of the attribute
        # @return String
        def box_folder_id(attribute_name = nil)
          box_folder(attribute_name).folder_id
        end

        def box_file(attribute_name)
          box_folder_root.file(attribute_name)
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Boxable::ActsAsBoxable