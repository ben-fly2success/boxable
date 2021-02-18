class BoxFolder < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  belongs_to :boxable, polymorphic: true, optional: true

  # The name is the internal identifier of the folder, it must be present
  validates_presence_of :name, :folder_id

  has_many :box_folders, foreign_key: :parent_id, dependent: :destroy
  has_many :box_files, foreign_key: :parent_id, dependent: :destroy

  after_initialize do
    create_folder
  end
  after_destroy do
    destroy_folder
  end

  def create_folder
    unless self.folder_id
      # Retrieve (or create) the folder if not given
      self.folder_id = Boxable::Helper.get_folder_or_create(name, parent.folder_id).id
    end
  end

  def destroy_folder
    client = BoxToken.client
    begin
      client.delete_folder(client.folder_from_id(folder_id), recursive: true)
    rescue Boxr::BoxrError
      puts "Can't destroy Box folder: #{folder_id}"
    end
  end

  # @abstract Get a sub folder
  # @param [Symbol] name - Name of the folder to retrieve
  # @return [BoxFolder || NilClass]
  def folder(name)
    box_folders.find_by(name: name)
  end

  # @abstract Get or create a sub folder
  # @param [Symbol] name - Name of the folder to retrieve
  # @note A BoxFolder will be created if not present
  # @return [BoxFolder]
  def sub(name)
    folder(name) || box_folders.send(boxable&.new_record? ? 'build' : 'create!', name: name, parent: self)
  end

  # @abstract Get a file in the folder
  # @param [Symbol] name - Name of the file to retrieve
  # @param [ApplicationRecord] boxable - Associated object
  # @return [BoxFile || NilClass]
  def file(name, boxable = nil)
    box_files.find_by(boxable: boxable, name: name)
  end

  # @abstract Add or update a file in the folder
  # @param [Symbol] name - Internal name of the file (will be used for Box file default name)
  # @param [String] file_id - ID of the file to add
  # @option [ApplicationRecord] boxable - Object to which the file is attached
  # @option [Bool] generate_url - Indicate whether a shared link should be created or not
  # @return [BoxFile || NilClass]
  def add_file(name, file_id, boxable = nil, filename: nil, generate_url: false)
    res = file(name, boxable)
    if res
      return res if res.file_id == file_id

      res.destroy
    end
    res = nil
    if file_id && file_id != ""
      res = box_files.create!(name: name,
                              filename: filename,
                              file_id: file_id,
                              boxable: boxable,
                              generate_url: generate_url)
    end
    res
  end

  # @abstract Print the tree of items below the folder
  # @option [Boolean] verbose
  # @return [NilClass]
  def print_tree(depth = 0, verbose: false)
    res = []
    res << "#{'    ' * depth}#{name}"
    box_folders.each do |sub|
      res += sub.print_tree(depth + 1, verbose: verbose)
    end
    box_files.each do |f|
      res << "#{'    ' * (depth + 1)}#{verbose ? "#{f.name}: " : ""}#{f.full_name}"
    end
    puts res.join("\n") if depth == 0
    res if depth > 0
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

  def update_with_folder_id(new_id, client: nil)
    update_columns(folder_id: new_id)

    client ||= Boxr::Client.new(BoxToken.token.access_token)
    folder_items = client.folder_items(new_id)
    box_folders.each do |sub|
      sub.update_with_folder_id(Boxable::Helper.sub_folder(sub.name, folder_items).id, client: client)
    end

    box_files.each do |sub|
      f = Boxable::Helper.sub_folder(sub.full_name, folder_items)
      sub.update_columns(file_id: f.id)

      # Update versions
      sub.versions.each do |v|
        if v.current
          v.update_columns(version_id: f.file_version["id"], sequence_id: "0")
        else
          # destroy all previous version (they are not migrated)
          v.destroy!
        end
      end
    end
  end

  def self.update_root
    # update tree structure with id from box
    client = Boxr::Client.new(BoxToken.token.access_token)

    # reset the folder name of the current env if initializing from prod
    folder = BoxFolder.where(parent_id: nil).first
    folder.name = Boxable.root
    folder.save!

    root.update_with_folder_id(client.folder_from_path(Boxable.root).id, client: client)

    # Update shared links
    retries = 0
    max_retries = 10
    BoxFile.where.not(url:nil).each do |file|
      begin
        file.url = client.create_shared_link_for_file(file.file_id, access: :open).shared_link.download_url
        file.save!
      rescue Boxr::BoxrError => e
        if (retries += 1) <= max_retries
          puts "Timeout (#{e}), retrying in #{retries} second(s)..."
          sleep(retries)
          retry
        else
          raise
        end
      end
    end
  end

  # @abstract Get BoxFolder record for temporary folder.
  # @return BoxFolder
  def self.temp
    root.sub(:temp_upload)
  end

  def token_for(rights, instance: false)
    BoxToken.for(folder_id, :folder, rights, instance: instance)
  end

  def token(instance: false)
    token_for(nil, instance: instance)
  end
end
