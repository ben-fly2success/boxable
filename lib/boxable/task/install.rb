class Boxable::Task::Install
  module Methods
    def perform
      client = Boxr::Client.new(BoxToken.token.access_token)
      res = {}
      root = client.folder_from_path(root_name)
      res['BOX_ROOT_FOLDER'] = root.id
      res['BOX_TEMP_FOLDER'] = Boxable::Helper.get_folder_or_create('temp_upload', root, client: client).id
      folder_classes_ids(client, root).each do |k, v|
        res["BOX_#{k}_FOLDER"] = v
      end
      f = File.open(Boxable::Helper.config_path, 'w+')
      f.write(res.to_yaml)
      f.close
    end

    private

    def root_name
      if Rails.env == "development"
        "Fly2Success - Server Files - #{Rails.env} - #{ENV['DEVELOPER_NAME']}"
      else
        "Fly2Success - Server Files - #{Rails.env}"
      end
    end

    def boxable_root_classes
      res = []
      ActiveRecord::Base.connection.tables.map do |table_name|
        constant = table_name.classify.constantize rescue nil
        if constant && constant.respond_to?(:boxable_config) && constant.boxable_config.parent.nil?
          res << constant
        end
      end
      res
    end

    def folder_classes_ids(client, folder)
      folder_items = client.folder_items(folder)
      boxable_root_classes.map do |c|
        [c.table_name.upcase, Boxable::Helper.get_folder_or_create(c.table_name, folder, folder_items: folder_items, client: client).id]
      end.to_h
    end
  end

  extend Methods
end