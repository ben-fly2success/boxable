class BoxFile < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  bound_to_boxable

  # The name is the internal identifier of the file, it must be present
  validates_presence_of :name

  before_save do
    update_file
  end
  after_destroy do
    destroy_file
  end

  def update_file
    client = BoxToken.client
    unless basename
      # Let the final name of the file in Box be the internal identifier if not given
      self.basename = name
    end
    self.full_name = "#{basename}#{File.extname(client.file_from_id(file_id).name).downcase}"
    self.file_id = client.update_file(file_id, name: full_name, parent: parent.folder_id).id

    if generate_url
      self.url = client.create_shared_link_for_file(file_id, access: :open).shared_link.download_url
    end
  end

  def destroy_file
    client = BoxToken.client
    begin
      client.delete_file(file_id)
    rescue Boxr::BoxrError
      puts "Can't destroy Box file: #{file_id}"
    end
  end
end