module Box
  module ActsAsBoxable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_boxable(options = {})
        class_eval do
          cattr_accessor :boxable_config
          self.boxable_config = Boxable::BoxableConfig.new(options)
          after_commit :create_box_folder, on: :create

          extend FriendlyId
          friendly_id :full_name, use: :slugged

          prepend InstanceMethods

          private

          def create_box_folder
            parent = get_box_parent
            self.box_folder = create_folder(self.slug, parent)
          end

          def get_box_parent
            if boxable_config.parent
              parent_association = reflect_on_all_associations.select{ |a| a.name == boxable_config.parent.to_sym }
              raise "Association '#{boxable_config.parent}' not found for class #{self.class.name}" unless parent_association
              #associated_name =
              self.send(parent_association)
              BoxCommunication.instance.client.folder_from_id()
            else
              BoxCommunication.instance.client.folder_from_path("#{BoxCommunication.instance.box_root_folder}/#{self.class.table_name}")
            end
          end
        end
      end

      module InstanceMethods
      end
    end
  end
end

ActiveRecord::Base.send :include, Boxable::ActsAsBoxable