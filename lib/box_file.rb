class BoxFile < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  belongs_to :boxable, polymorphic: true, optional: true

  has_many :versions, class_name: 'BoxFileVersion', dependent: :destroy

  # The name is the internal identifier of the file, it must be present
  validates_presence_of :name, :file_id

  after_destroy do
    destroy_file
  end

  def destroy_file
    client = BoxToken.client
    begin
      client.delete_file(file_id)
    rescue Boxr::BoxrError
      puts "Can't destroy Box file: #{file_id}"
    end
  end

  def token_for(rights, instance: false)
    BoxToken.for(file_id, :file, rights, instance: instance)
  end

  def token(instance: false)
    token_for(nil, instance: instance)
  end

  def build_version(file, filename: nil, is_file_box_id: false, generate_url: false)
    previous_version = current_version&.version_id
    versions << BoxFileVersion.new(box_file: self,
                                   file: file,
                                   filename: filename,
                                   previous_version: previous_version,
                                   is_file_box_id: is_file_box_id,
                                   generate_url: generate_url)
  end

  def current_version
    versions.find_by(current: true)
  end

  def full_name
    current_version.full_name
  end
end