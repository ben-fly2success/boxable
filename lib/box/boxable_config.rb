module Box
  class BoxableConfig
    attr_reader :parent

    def initialize(options = {})
      @parent = options[:parent]
    end
  end
end
