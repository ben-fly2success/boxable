class BoxFile < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  belongs_to :boxable, polymorphic: true, optional: true

  before_save do
    update_file
  end
  after_destroy do
    destroy_file
  end

  def name_from_boxable
    if name_method
      boxable.send(name_method)
    else
      name
    end
  end

  def update_file
    client = BoxToken.client
    self.file_id = client.update_file(file_id, name: "#{name_from_boxable}#{File.extname(client.file_from_id(file_id).name).downcase}", parent: self.parent.folder_id).id
    self.url = client.create_shared_link_for_file(self.file_id, access: :open).shared_link.download_url
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