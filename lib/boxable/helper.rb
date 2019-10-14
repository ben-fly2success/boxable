module Boxable
  class Helper
    def self.items_names(items)
      items.map { |i| i.name }
    end

    # Use this to get a sub folder
    def self.sub_folder(sub_name, box_folder_items)
      folders = box_folder_items.map{|f| f if f.name.downcase == sub_name.downcase}.compact

      raise Boxable::Error.new("Folder '#{sub_name}' not found in items '#{items_names(box_folder_items)}'") if folders.count == 0
      raise Boxable::Error.new("Too many folders (#{folders.count}) for '#{sub_name}' in items '#{items_names(box_folder_items)}'") if folders.count > 1

      folders[0]
    end

    def self.destroy_or_ignore_sub_folder(name, items, client: BoxToken.client)
      begin
        client.delete_folder(Boxable::Helper.sub_folder(name, items))
      rescue Boxr::BoxrError => e
        puts "Can't destroy folder '#{name}' in #{items_names(items)}: #{e}"
      end
    end

    def self.get_folder_or_create(name, parent, client: BoxToken.client, folder_items: client.folder_items(parent))
      begin
        Boxable::Helper.sub_folder(name, folder_items)
      rescue Boxable::Error
        client.create_folder(name, parent)
      end
    end

    def self.config_path
      'config/boxable.yml'
    end
  end
end