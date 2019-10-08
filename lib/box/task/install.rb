class Box::Task::Install
  def self.perform
    client = Boxr::Client.new(BoxToken.token.access_token)
    res = {}
    root = client.folder_from_path(root_name)
    res['BOX_ROOT_FOLDER'] = root.id
    f = File.open('config/box.yml', 'w+')
    f.write(res.to_yaml)
    f.close

    BoxToken.all.each &:destroy
    root_entry = BoxToken.new
    root_entry.folder = root.id
    root_entry.save!
  end

  private

  def self.root_name
    if Rails.env == "development"
      "Fly2Success - Server Files - #{Rails.env} - #{ENV['DEVELOPER_NAME']}"
    else
      "Fly2Success - Server Files - #{Rails.env}"
    end
  end
end