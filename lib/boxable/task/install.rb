class Boxable::Task::Install
  module Methods
    def perform
      client = Boxr::Client.new(BoxToken.token.access_token)
      res = {}
      root = client.folder_from_path(root_name)
      res['BOX_ROOT_FOLDER'] = root.id
      res['BOX_TEMP_FOLDER'] = folder_id_in_folder('temp_upload', root, client)
      folder_classes_ids(client, root).each do |k, v|
        res["BOX_#{k}_FOLDER"] = v
      end
      f = File.open(Boxable::Helper.config_path, 'w+')
      f.write(res.to_yaml)
      f.close

      BoxToken.all.each &:destroy
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
        [c.table_name.upcase, folder_id_in_folder(c.table_name, folder, client, folder_items: folder_items)]
      end.to_h
    end

    def folder_id_in_folder(name, folder, client, folder_items: client.folder_items(folder))
      begin
        Boxable::Helper.sub_folder(name, folder_items).id
      rescue Boxable::Error
        client.create_folder(name, folder).id
      end
    end
  end

  extend Methods
end