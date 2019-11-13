module Boxable
  class AttachmentTask
    def initialize(type, name, name_method, value, generate_url: false)
      @type = type
      @name = name
      @name_method = name_method
      @value = value
      @generate_url = generate_url
    end

    def perform_for(object)
      case @type
      when :one_file
        object.boxable.stub.files[@name] = object.build_box_file(object.box_folder_root, @name, @value, basename: @name_method && object.send(@name_method), generate_url: @generate_url)
      when :one_picture
        object.boxable.stub.pictures[@name] = object.build_box_file(object.box_folder_root.sub(@name), 'original', @value, generate_url: @generate_url)
      else
        raise "Unknown task type: '#{@type}'"
      end
    end

    def self.schedule_for(object, type, name, name_method, value, generate_url: false)
      task = self.new(type, name, name_method, value, generate_url: generate_url)
      if object.new_record?
        object.boxable.deferred_attachments << task
      else
        task.perform_for object
      end
    end
  end
end