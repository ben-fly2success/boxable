class BoxFolder < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  belongs_to :boxable, polymorphic: true, optional: true

  has_many :box_folders, foreign_key: :parent_id, dependent: :destroy
  has_many :box_files, foreign_key: :parent_id, dependent: :destroy

  before_create do
    create_folder
  end
  after_destroy do
    destroy_folder
  end

  def name_from_boxable
    if name_method
      boxable.send(name_method)
    else
      name
    end
  end

  def create_folder
    unless self.folder_id
      self.folder_id = Boxable::Helper.get_folder_or_create(name_from_boxable, parent.folder_id).id
    end
  end

  def destroy_folder
    client = BoxToken.client
    begin
      client.delete_folder(client.folder_from_id(folder_id))
    rescue Boxr::BoxrError
      puts "Can't destroy Box folder: #{folder_id}"
    end
  end

  def sub(name)
    box_folders.find_by(name: name) || box_folders.create!(name: name)
  end

  def file(name)
    box_files.find_by(name: name)
  end

  def add_file(name, file_id, boxable = nil, name_method = nil)
    got = file(name)
    if got
      return if got.file_id == file_id

      got.destroy
    end
    if file_id && file_id != ""
      box_files.create!(name: name, file_id: file_id, boxable: boxable, name_method: name_method)
    end
  end

  def self.root
    res = find_by(parent: nil)
    raise 'No Box folder root defined.' unless res

    res
  end

  def self.temp
    root.sub('temp_folder')
  end
end