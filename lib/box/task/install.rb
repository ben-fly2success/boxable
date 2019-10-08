class Box::Task::Install
  def self.perform
    client = Boxr::Client.new(BoxToken.token.access_token)
    res = {}
    root = client.folder_from_path(root_name)
    res['BOX_ROOT_FOLDER'] = root.id
    folder_classes_ids(client, root).each do |k, v|
      res["BOX_#{k}_FOLDER"] = v
    end
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

  def self.boxable_root_classes
    res = []
    ActiveRecord::Base.connection.tables.map do |table_name|
      constant = table_name.classify.constantize rescue nil
      if constant && constant.respond_to?(:boxable_config) && constant.boxable_config.parent.nil?
        res << constant
      end
    end
    res
  end

  def self.folder_classes_ids(client, folder)
    folder_items = client.folder_items(folder)
    boxable_root_classes.map do |c|
      [c.table_name.upcase, Box::Helper.sub_folder(c.table_name, folder_items).id]
    end.to_h
  end
end