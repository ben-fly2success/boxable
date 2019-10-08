module Box
  module Task
    class Install
      def self.perform
        client = Boxr::Client.new(BoxToken.token.access_token)
        puts "CLIENT: #{client}"
        puts "ROOT: #{root_name}"
      end

      def self.root_name
        if Rails.env == "development"
          "Fly2Success - Server Files - #{Rails.env} - #{ENV['DEVELOPER_NAME']}"
        else
          "Fly2Success - Server Files - #{Rails.env}"
        end
      end
    end
  end
end
