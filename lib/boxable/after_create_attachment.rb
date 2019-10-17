module Boxable
  class AttachmentTask
    def initialize(type, name, name_method, value)
      @type = type
      @name = name
      @name_method = name_method
      @value = value
    end

    def perform_for(object)
      case @type
      when :one_file
        object.box_folder_root.add_file(@name, @value, object, @name_method)
      when :one_picture
        object.box_folder_root.sub(@name).add_file('original', @value, object, nil)
      else
        raise "Unknown task type: '#{@type}'"
      end
    end
  end
end