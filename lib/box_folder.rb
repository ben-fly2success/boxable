class BoxFolder < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true
  has_many :box_folders, as: :boxable, dependent: :destroy

  before_create do
    create_folder
  end
  after_destroy do
    destroy_folder
  end

  def create_folder
    parent_id = boxable.boxable_parent_id(attribute_name)
    self.parent = parent_id
    self.folder = Boxable::Helper.get_folder_or_create(attribute_name ? attribute_name : boxable.slug, parent_id).id
  end

  def destroy_folder
    if folder
      client = BoxToken.client
      client.delete_folder(client.folder_from_id(folder))
    end
  end

  def boxable_parent_id(attribute_name = nil)
    self.folder
  end

  def sub(attribute_name = nil)
    if attribute_name
      box_folders.find_by(attribute_name: attribute_name) || box_folders.create!(attribute_name: attribute_name)
    else
      self
    end
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