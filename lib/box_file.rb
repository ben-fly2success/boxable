class BoxFile < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true

  validates_presence_of :basename

  after_destroy do
    detach
  end

  def used_basename(given)
    if self.name_method
      boxable.send(self.name_method)
    else
      given ? given : basename
    end
  end

  def attach(temp_file, name: nil, generate_url: false)
    if temp_file.class.name == 'Array'
      temp_file, name, generate_url = temp_file
    end
    return if temp_file == self.file

    client = BoxToken.client
    detach
    if temp_file && temp_file != ""
      self.parent = boxable.box_folder
      self.file = client.update_file(temp_file, name: "#{used_basename(name)}#{File.extname(client.file_from_id(temp_file).name).downcase}", parent: self.parent).id
      if generate_url
        self.url = client.create_shared_link_for_file(self.file, access: :open).shared_link.download_url
      end
      self.save!
    else
      self.destroy!
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