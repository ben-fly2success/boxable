class BoxFile < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true

  validates_presence_of :basename

  after_commit :detach, on: :destroy

  def attach(temp_file, name: nil)
    client = BoxToken.client
    detach
    self.parent = boxable.box_folder
    self.file = client.update_file(temp_file, name: "#{name ? name : basename}#{File.extname(client.file_from_id(temp_file).name).downcase}", parent: self.parent).id
    self.save!
  end

  def detach
    if file
      client = BoxToken.client
      client.delete_file(file)
      self.parent = nil
      self.file = nil
      self.save!
    end
  end
end