module Boxable
  class BoxableConfig
    attr_accessor :parent
    attr_accessor :folder
    attr_accessor :name

    attr_accessor :box_files
    attr_accessor :box_file_collections
    attr_accessor :box_pictures

    attr_accessor :attr_params

    def initialize(options = {})
      self.parent = options[:parent]
      self.box_files = []
      self.box_file_collections = []
      self.box_pictures = []
      self.folder = options[:folder] || :unique
      self.name = options[:name]
      self.attr_params = {}
    end

    def attribute_type(name)
      return :box_file if name.in?(@box_files)
      return :box_file_collection if name.in?(@box_file_collections)
      return :box_picture if name.in?(@box_pictures)

      raise "Box attribute not found: #{name}"
    end

    def attributes
      self.box_files + self.box_file_collections
    end
  end
end
