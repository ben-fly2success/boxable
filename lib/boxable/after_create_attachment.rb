module Boxable
  class AttachmentTask
    def initialize(type, name, value)
      @type = type
      @name = name
      @value = value
    end

    def perform_for(object)
      case @type
      when :has_one
        dst = object.send(@name)
        unless dst
          dst = object.build_box_attached(@name)
        end
        dst.attach(@value)
      when :has_one_picture
        dst = object.send("#{@name}_definitions")
        unless dst
          dst = object.build_box_attached("#{@name}_definitions")
        end
        dst.add('original', @value, generate_url: true)
      else
        raise "Unknown task type: '#{@type}'"
      end
    end
  end
end