namespace :box do
  desc "Setup box folder"
  task install: :environment do
    Box::Task::Install.perform
  end
end