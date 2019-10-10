class BoxFileCollection < ActiveRecord::Base
  belongs_to :boxable, polymorphic: true
  has_many :box_files, as: :boxable, dependent: :destroy

  after_commit :create_folder, on: :create
  after_commit :destroy_folder, on: :destroy

  validates_presence_of :basename

  after_commit :detach, on: :destroy

  def all
    box_files
  end

  def find(key)
    box_files.find_by(basename: key)
  end

  def add(name, temp_file, generate_url: false)
    old = find(name)
    if old
      old.attach(temp_file, name: name, generate_url: generate_url)
    else
      file = box_files.build(basename: name)
      file.attach(temp_file, name: name, generate_url: generate_url)
      file
    end
  end

  def create_folder
    self.parent = boxable.box_folder
    self.folder = BoxToken.client.create_folder(basename, self.parent).id
    self.save!
  end

  def destroy_folder
    BoxToken.client.delete_folder(folder)
  end

  def box_folder
    folder
  end
end