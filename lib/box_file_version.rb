class BoxFileVersion < ActiveRecord::Base
  belongs_to :box_file

  validates_presence_of :version_id, :filename, :current

  attr_accessor :file
  attr_accessor :is_file_box_id
  attr_accessor :generate_url

  after_initialize do
    if is_file_box_id
      update_version_from_box_id
    else
      update_version
    end
  end

  after_commit on: :destroy do
    unless sequence_id.in?(['0', '1'])
      client = BoxToken.root.client
      client.delete_old_version_of_file(box_file.file_id, version_id)
    end
  end

  def full_name
    "#{filename}#{extension}"
  end

  private

  def update_version
    return if version_id

    client = BoxToken.root.client

    self.filename ||= box_file.name
    self.extension = File.extname(file.original_filename).downcase

    latest_version = if box_file.file_id
                       client.upload_new_version_of_file(file.path, box_file.file_id, name: full_name)
                     else
                       first_file = client.upload_file(file.path, box_file.parent.folder_id, name: full_name)
                       box_file.file_id = first_file.id
                       box_file.url = client.create_shared_link_for_file(first_file.id, access: :open).shared_link.download_url
                       first_file
                     end
    update_current_version(latest_version)
  end

  def update_version_from_box_id
    client = BoxToken.root.client

    self.filename ||= box_file.name
    self.extension = ".#{box_file.boxable.file_type}".downcase

    latest_version = client.update_file(file, name: full_name, parent: box_file.parent.folder_id)
    box_file.file_id = latest_version.id
    if generate_url
      box_file.url = client.create_shared_link_for_file(latest_version.id, access: :open).shared_link.download_url
    end

    update_current_version(latest_version)
  end

  def update_current_version(latest_version)
    self.version_id = latest_version.file_version.id
    self.sequence_id = latest_version.sequence_id

    box_file.boxable.last_uploaded_version = self.version_id

    box_file.versions.each do |ver|
      ver.update_columns(current: false) unless ver.new_record?
    end
    self.current = true
  end
end