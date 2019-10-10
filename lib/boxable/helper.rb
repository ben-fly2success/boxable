module Boxable
  class Helper
    # Use this to get a sub folder
    def self.sub_folder(sub_name, box_folder_items)
      folders = box_folder_items.map{|f| f if f.name.downcase == sub_name.downcase}.compact

      raise Boxable::Error.new("Folder '#{sub_name}' not found in items '#{box_folder_items}'") if folders.count == 0
      raise Boxable::Error.new("Too many folders (#{folders.count}) for '#{sub_name}' in items '#{box_folder_items}'") if folders.count > 1

      folders[0]
    end

    def self.config_path
      'config/boxable.yml'
    end
  end
end