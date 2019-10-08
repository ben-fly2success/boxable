module Box
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/box.rake'
    end
  end
end