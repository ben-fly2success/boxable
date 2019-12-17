module Boxable
  class InstanceBase
    class Stub
      attr_accessor :files
      attr_accessor :pictures

      def initialize
        self.files = {}
        self.pictures = {}
      end
    end

    attr_accessor :stub
    attr_accessor :deferred_attachments
    attr_accessor :attachments

    def initialize
      self.stub = Boxable::InstanceBase::Stub.new
      self.deferred_attachments = []
      self.attachments = []
    end
  end
end
