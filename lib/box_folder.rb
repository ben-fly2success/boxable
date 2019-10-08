class BoxFolder < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true

  after_commit :create_folder, on: :create
  after_commit :destroy_folder, on: :destroy

  attr_accessor :name

  def create_folder
    client = BoxToken.root.client
    p = box_parent
    self.parent = p.id
    self.folder = client.create_folder(@name ? @name : boxable.slug, p).id
    self.save!
  end

  def destroy_folder
    client = BoxToken.root.client
    client.delete_folder(client.folder_from_id(folder))
  end

  private

  def box_parent
    client = BoxToken.root.client
    if self.parent == 'box_folder'
      client.folder_from_id(boxable.box_folder.folder)
    else
      if boxable.boxable_config.parent
        parent_association = boxable.class.reflect_on_all_associations.select{ |a| a.name == boxable.boxable_config.parent }.first
        raise "Association '#{boxable_config.parent}' not found for class #{boxable.class.name}" unless parent_association

        associated_name = parent_association.options[:inverse_of]
        raise "No inverse_of defined on association '#{parent_association.name}' for class #{boxable.class.name}" unless associated_name

        parent_folder = boxable.send(parent_association.name.to_sym).send("box_#{associated_name}_folder".to_sym)
        client.folder_from_id(parent_folder.folder)
      else
        root = client.folder_from_id(BoxToken.root.folder)
        Box::Helper.sub_folder(boxable.class.table_name, client.folder_items(root))
      end
    end
  end
end