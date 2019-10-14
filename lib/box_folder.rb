class BoxFolder < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true

  after_commit :create_folder, on: :create
  after_commit :destroy_folder, on: :destroy

  attr_accessor :name

  def create_folder
    parent_id = boxable.boxable_parent_id(attribute_name)
    self.parent = parent_id
    self.folder = Boxable::Helper.get_folder_or_create(attribute_name ? attribute_name : boxable.slug, parent_id).id
    self.save!
  end

  def destroy_folder
    client = BoxToken.client
    client.delete_folder(client.folder_from_id(folder))
  end

  def self.env_folder(name)
    key = "BOX_#{name}_FOLDER"
    res = ENV[key]
    raise "No Box folder '#{key}' in ENV" unless res

    res
  end

  def self.root
    env_folder('ROOT')
  end

  def self.temp
    env_folder('TEMP')
  end
end