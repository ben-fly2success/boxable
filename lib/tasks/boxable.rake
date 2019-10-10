namespace :boxable do
  desc "Setup box folder"
  task install: :environment do
    Boxable::Task::Install.perform
  end
end