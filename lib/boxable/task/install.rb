class Boxable::Task::Install
  module Methods
    def perform
      BoxFolder.all.each &:delete
      client = Boxr::Client.new(BoxToken.token.access_token)
      root = client.folder_from_path(root_name)
      BoxFolder.create(name: Boxable::Helper.root_name, parent: nil, folder_id: root.id)
    end

    private

    def root_name
      if Rails.env == "development"
        "Fly2Success - Server Files - #{Rails.env} - #{ENV['DEVELOPER_NAME']}"
      else
        "Fly2Success - Server Files - #{Rails.env}"
      end
    end
  end

  extend Methods
end