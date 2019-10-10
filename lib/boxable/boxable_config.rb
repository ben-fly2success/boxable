module Boxable
  class BoxableConfig
    attr_reader :parent

    def initialize(options = {})
      @parent = options[:parent]
      @folders = {}
    end
  end
end
