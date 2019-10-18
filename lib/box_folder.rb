class BoxFolder < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  bound_to_boxable

  has_many :box_folders, foreign_key: :parent_id, dependent: :destroy
  has_many :box_files, foreign_key: :parent_id, dependent: :destroy

  before_create do
    create_folder
  end
  after_destroy do
    destroy_folder
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

  # @abstract Get a sub folder
  # @param [Symbol] name - Name of the folder to retrieve
  # @return BoxFolder or nil
  def folder(name)
    box_folders.find_by(name: name)
  end

  # @abstract Get or create a sub folder
  # @param [Symbol] name - Name of the folder to retrieve
  # @note A BoxFolder will be created if not present
  # @return BoxFolder
  def sub(name)
    folder(name) || box_folders.send(boxable&.new_record? ? 'build' : 'create!', name: name)
  end

  # @abstract Get a file in the folder
  # @param [Symbol] name - Name of the file to retrieve
  # @return BoxFile or nil
  def file(name)
    box_files.find_by(name: name)
  end

  # @abstract Add or update a file in the folder
  # @param [String] name - Internal name of the file (will be used for Box file default name)
  # @param [String] file_id - ID of the file to add
  # @option [ApplicationRecord] boxable - Object to which the file is attached
  # @option [Symbol] name_method - Name of the method to call on boxable to get Box file name
  # @return BoxFile or nil
  def add_file(name, file_id, boxable = nil, name_method = nil)
    res = file(name)
    if res
      return res if res.file_id == file_id

      res.destroy
    end
    res = nil
    if file_id && file_id != ""
      res = box_files.create!(name: name, file_id: file_id, boxable: boxable, name_method: name_method)
    end
    res
  end

  # @abstract Print the tree of items below the folder
  def print_tree(depth = 0)
    res = []
    res << "#{'    ' * depth}#{self.name_from_boxable}"
    box_folders.each do |sub|
      res += sub.print_tree(depth + 1)
    end
    box_files.each do |f|
      res << "#{'    ' * (depth + 1)}#{f.name_from_boxable}"
    end
    puts res.join("\n") if depth == 0
    res
  end

  # @abstract Get BoxFolder record for root.
  # @return BoxFolder
  def self.root
    res = find_by(parent: nil, name: Boxable.root)
    unless res
      client = Boxr::Client.new(BoxToken.token.access_token)
      root = client.folder_from_path(Boxable.root)
      res = BoxFolder.create(name: Boxable.root, parent: nil, folder_id: root.id)
    end

    res
  end

  # @abstract Get BoxFolder record for temporary folder.
  # @return BoxFolder
  def self.temp
    root.sub('temp_upload')
  end
end