require 'singleton'

module Box
  class Communication < ActiveRecord
    include Singleton

    def initialize
      @client_mutex = Mutex.new
      init_box
    end

    attr_reader :client
    attr_reader :token

    attr_accessor :box_pictures_folder_name

    attr_accessor :box_user_folder_name
    attr_accessor :box_company_folder_name

    attr_accessor :box_folder_administrative_name
    attr_accessor :box_folder_drones_name
    attr_accessor :box_folder_missions_name

    attr_accessor :box_folder_items_limit

    attr_accessor :box_root_folder

    attr_accessor :box_temp_folder_name
    attr_accessor :box_companies_folder_name
    attr_accessor :box_users_folder_name

    attr_accessor :box_temp_folder
    attr_accessor :box_companies_folder
    attr_accessor :box_users_folder

    attr_accessor :offline

    attr_accessor :box_root_folder_id
    attr_accessor :box_temp_folder_id
    attr_accessor :box_companies_folder_id
    attr_accessor :box_users_folder_id

    def refresh_client
      @client_mutex.synchronize do
        renew_token
        @client = Boxr::Client.new(@token.access_token)
        Sidekiq::Queue.new('box_client').clear
        schedule_refresh_job unless Sidekiq.server?
      end
    end

    def job_id
      @job.provider_job_id
    end

    def test_alter_token
      @client = Boxr::Client.new('ABCD')
    end

    def self.assert_fetch_limit(table)
      raise "#{table.class} has more than #{self.instance.box_folder_items_limit} entries (Box maximum per query)" if table.all.count > self.instance.box_folder_items_limit
    end

    # Use this to get a sub folder
    def self.sub_folder(sub_name, box_folder_items)
      folders = box_folder_items.map{|f| f if f.name.downcase == sub_name.downcase}.compact

      raise "Folder '#{sub_name}' not found in items '#{box_folder_items}'" if folders.count == 0
      raise "Too many folders (#{folders.count}) for '#{sub_name}' in items '#{box_folder_items}'" if folders.count > 1

      folders[0]
    end

    def self.reset_environment
      # Delete all links to prod environement to avoid any change to prod files
      Company.find_each do |c|
        c.box_folder = nil
        c.box_administrative_folder = nil
        c.save!
      end
      puts 'Companies reseted'

      Drone.find_each do |c|
        c.box_folder = nil
        c.save!
      end
      puts 'Drones reseted'

      Pilot.find_each do |c|
        c.box_folder = nil
        c.box_administrative_folder = nil
        c.box_mission_folder = nil
        c.save!
      end
      puts 'Pilots reseted'

      # Boxr client
      client = BoxCommunication.instance.client

      # Get all clients
      assert_fetch_limit(Company)
      companies_ids = client.folder_items_from_id(self.instance.box_companies_folder_id)
      Company.all.each do |company|
        reset_company(company, sub_folder(company.box_root_name, companies_ids))
      end

      # Get folder id for each pilot
      assert_fetch_limit(User)
      users_mails = client.folder_items_from_id(self.instance.box_users_folder_id)
      ActiveRecord::Base.transaction do
        User.all.includes(:documents).references(:documents).select(:id, :documents).each do |pilot|
          puts "reseting #{pilot.email}"

          # Get to user folder
          user_root = sub_folder(pilot.email, users_mails)
          root_items = client.folder_items(user_root)
          user_folder = sub_folder(self.instance.box_user_folder_name, root_items)
          pictures_folder = sub_folder(self.instance.box_pictures_folder_name, root_items)

          # Get 'Administratif' and 'Missions' folders
          user_items = client.folder_items(user_folder)
          box_folder = user_folder.id
          mission_folder = sub_folder(self.instance.box_folder_missions_name, user_items).id
          admin_folder = sub_folder(self.instance.box_folder_administrative_name, user_items)

          # Save Box calls when no documents are present
          if !pilot.documents.select(:id).empty?
            admin_items = client.folder_items(admin_folder.id)
            # Send all documents in items to save calls
            pilot.box_update_documents(admin_folder.id, admin_items)
          end
          pilot.update_columns(box_folder: user_folder.id, box_pictures_folder: pictures_folder.id, box_mission_folder: mission_folder, box_administrative_folder: admin_folder.id)
          puts "#{pilot.email} successfully initialized"
        end
      end

      reset_pictures
    end

    def self.migrate_attachments
      # Get Box handler
      client = self.instance.client
      prod = ProductionActions.instance

      User.all.each do |user|
        prod.add_job(BoxMigrateAttachedUserWorker.perform_async(user.id))
      end
      Company.all.each do |company|
        prod.add_job(BoxMigrateAttachedCompanyWorker.perform_async(company.id))
      end
      prod.wait_jobs
    end

    def self.get_all_orphans
      res = Array.new
      User.all.each do |user|
        res += get_folder_orphans(BoxDriver.new(user.box_administrative_folder), user.documents)
      end
      Company.all.each do |company|
        res += get_folder_orphans(BoxDriver.new(company.box_administrative_folder), company.documents)
      end
      Drone.all.each do |drone|
        res += get_folder_orphans(BoxDriver.new(drone.box_folder), drone.documents)
      end
      res
    end

    def self.create_client
      token = Boxr.get_enterprise_token(private_key: ENV['BOX_PRIVATE_KEY'],
                                        private_key_password: ENV['BOX_PASSPHRASE'],
                                        public_key_id: ENV['BOX_PUBLIC_KEY_ID'],
                                        enterprise_id: ENV['BOX_ENTERPRISE_ID'],
                                        client_id: ENV['BOX_CLIENT_ID'],
                                        client_secret: ENV['BOX_CLIENT_SECRET'])
      Boxr::Client.new(token.access_token)
    end

    private

    def renew_token
      @token = Boxr.get_enterprise_token(private_key: ENV['BOX_PRIVATE_KEY'],
                                         private_key_password: ENV['BOX_PASSPHRASE'],
                                         public_key_id: ENV['BOX_PUBLIC_KEY_ID'],
                                         enterprise_id: ENV['BOX_ENTERPRISE_ID'],
                                         client_id: ENV['BOX_CLIENT_ID'],
                                         client_secret: ENV['BOX_CLIENT_SECRET'])
      @date_to_refresh = DateTime.now + @token.expires_in.seconds - 5.minutes
      puts "Token will expire in #{@token.expires_in.seconds / 60}min and will be renewed at #{I18n.l(@date_to_refresh, locale: :fr)}"
    end

    def schedule_refresh_job
      return if defined?(Sidekiq::Testing)
      @job = BoxWorker.perform_at(@date_to_refresh)
    end

    # Refresh company Box attributes (id, sub folders, documents)
    def self.reset_company(company, folder)
      # Get 'Fly2Success - Mes fichiers société' folder
      client = self.instance.client
      folder_items = client.folder_items(folder)
      company.box_pictures_folder = sub_folder(self.instance.box_pictures_folder_name, folder_items).id
      folder = sub_folder(self.instance.box_company_folder_name, folder_items)
      folder_items = client.folder_items(folder)
      company.box_folder = folder.id

      # Get all administrative papers and search among them
      administrative_folder = sub_folder(self.instance.box_folder_administrative_name, folder_items)
      administrative_folder_items = client.folder_items(administrative_folder)
      company.box_administrative_folder = administrative_folder.id
      company.box_update_documents(administrative_folder.id, administrative_folder_items)
      company.save!
      puts "#{company.box_root_name} successfully initialized"

      if company.drones.count > 0
        drones_folder = sub_folder(self.instance.box_folder_drones_name, folder_items)
        reset_company_drones(company, drones_folder)
      end
    end

    def self.reset_company_drones(company, folder)
      client = self.instance.client
      # Find folder id for each drone
      drone_items = client.folder_items(folder)
      company.drones.each do |drone|

        # Get all documents related to the drone
        drone_folder = sub_folder(drone.box_root_name, drone_items)
        drone_folder_items = client.folder_items(drone_folder)
        drone.box_folder = drone_folder.id

        # Send them to the Document model so them can be updated
        drone.box_update_documents(drone_folder.id, drone_folder_items)
        drone.save!
      end
    end

    # Implicit usage : a valid BoxDriver is expected for folder, documents is array of Document
    def self.get_folder_orphans(folder, documents)
      documents.map{ |doc| folder.sub(doc.full_name) if !folder.has_item(doc.full_name) }.compact
    end

    # Refresh all pictures attributes related to Box (id and path)
    def self.reset_pictures
      # Box client
      client = self.instance.client

      # Reset all pictures independently
      Picture.all.each do |picture|
        parent_folder = client.folder_from_id(picture.imageable.box_pictures_folder)
        parent_items = client.folder_items(parent_folder)
        parent_items.each_with_index do |item, i|
          name = parent_items[i].name
          # Remove extension from each item (so we can compare them with picture types)
          parent_items[i].name = File.basename(name, File.extname(name))
        end
        # Search for desired picture type in folder
        file = sub_folder(picture.picture_type.name, parent_items)
        # Update Box id / path
        file_id = file.id
        file_path = client.create_shared_link_for_file(file_id, access: :open).shared_link.download_url
        # Use update_columns to avoid after_commit
        picture.update_columns(box_file_id: file_id, box_file_path: file_path)
      end
    end

    private
    def init_box
      self.box_pictures_folder_name = 'pictures'

      self.box_user_folder_name = 'Fly2Success - Mes fichiers'
      self.box_company_folder_name = 'Fly2Success - Mes fichiers société'

      self.box_folder_administrative_name = 'Administratif'
      self.box_folder_drones_name = 'Drones'
      self.box_folder_missions_name = 'Missions'

      self.box_folder_items_limit = 1000

      if Rails.env == "development"
        self.box_root_folder = "Fly2Success - Server Files - #{Rails.env} - #{ENV['DEVELOPER_NAME']}"
      else
        self.box_root_folder = "Fly2Success - Server Files - #{Rails.env}"
      end

      self.box_temp_folder_name = "temp_upload"
      self.box_companies_folder_name = "companies"
      self.box_users_folder_name = "users"

      self.box_temp_folder = "#{self.box_root_folder}/#{self.box_temp_folder_name}"
      self.box_companies_folder = "#{self.box_root_folder}/#{self.box_companies_folder_name}"
      self.box_users_folder = "#{self.box_root_folder}/#{self.box_users_folder_name}"

      #Sidekiq::Queue.new('box_client').clear
      #Sidekiq::RetrySet.new.clear
      #Sidekiq::ScheduledSet.new.clear


      init_box_files = false
      refresh_client
      has_root = true
      begin
        f = self.client.folder_from_path(self.box_root_folder)
        init_box_files = true if self.client.folder_items(f).count < 3
      rescue StandardError => e
        puts "Error : #{e}"
        has_root = false
        init_box_files = true
      end

      if init_box_files
        unless has_root
          f = self.client.create_folder(self.box_root_folder, 0)
          if Rails.env.development? || Rails.env.test?
            self.client.add_collaboration(f, { type: 'user', login: ENV['DEVELOPER_EMAIL'] }, 'co-owner')
          else
            self.client.add_collaboration(f, { type: 'user', login: "benjamin@fly2success.io" }, 'co-owner')
          end
        end

        self.client.create_folder('temp_upload', f)
        self.client.create_folder('companies', f)
        self.client.create_folder('users', f)
      end

      self.box_root_folder_id = self.client.folder_from_path(self.box_root_folder).id
      self.box_temp_folder_id = self.client.folder_from_path(self.box_temp_folder).id
      self.box_companies_folder_id = self.client.folder_from_path(self.box_companies_folder).id
      self.box_users_folder_id = self.client.folder_from_path(self.box_users_folder).id
    end
  end
end
