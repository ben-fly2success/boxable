class BoxFile < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true

  validates_presence_of :basename

  after_commit :detach, on: :destroy

  def attach(temp_file, name: nil, generate_url: false)
    if temp_file.class.name == 'Array'
      temp_file, generate_url = temp_file
    end
    return if temp_file == self.file

    client = BoxToken.client
    detach
    if temp_file && temp_file != ""
      self.parent = boxable.box_folder
      self.file = client.update_file(temp_file, name: "#{name ? name : basename}#{File.extname(client.file_from_id(temp_file).name).downcase}", parent: self.parent).id
      if generate_url
        self.url = client.create_shared_link_for_file(self.file, access: :open).shared_link.download_url
      end
      self.save!
    end
  end

  def detach
    if file
      client = BoxToken.client
      client.delete_file(file)
      self.parent = nil
      self.file = nil
      self.url = nil
      self.save!
    end
  end
end