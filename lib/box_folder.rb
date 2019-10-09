class BoxFolder < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true

  after_commit :create_folder, on: :create
  after_commit :destroy_folder, on: :destroy

  attr_accessor :name
  attr_accessor :parent_name

  def create_folder
    client = BoxToken.root.client
    parent_id = boxable.box_parent_id(@parent_name)
    self.parent = parent_id
    self.folder = client.create_folder(@name ? @name : boxable.slug, parent_id).id
    self.save!
  end

  def destroy_folder
    client = BoxToken.root.client
    client.delete_folder(client.folder_from_id(folder))
  end
end