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
        object.send(@name).attach(@value)
      when :has_one_picture
        object.send("#{@name}_definitions").add('original', @value, generate_url: true)
      else
        raise "Unknown task type: '#{@type}'"
      end
    end
  end
end