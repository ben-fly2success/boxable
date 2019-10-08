module Box
  class Helper
    # Use this to get a sub folder
    def self.sub_folder(sub_name, box_folder_items)
      folders = box_folder_items.map{|f| f if f.name.downcase == sub_name.downcase}.compact

      raise "Folder '#{sub_name}' not found in items '#{box_folder_items}'" if folders.count == 0
      raise "Too many folders (#{folders.count}) for '#{sub_name}' in items '#{box_folder_items}'" if folders.count > 1

      folders[0]
    end
  end
end