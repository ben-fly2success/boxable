class BoxFile < ActiveRecord::Base
  belongs_to :parent, class_name: 'BoxFolder', optional: true
  belongs_to :boxable, polymorphic: true, optional: true

  has_many :versions, class_name: 'BoxFileVersion', dependent: :destroy

  # The name is the internal identifier of the file, it must be present
  validates_presence_of :name, :file_id, :url

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

  def build_version(file, filename: nil)
    versions.build(file: file, filename: filename)
  end

  def current_version
    versions.find_by(current: true)
  end

  def full_name
    current_version.full_name
  end
end