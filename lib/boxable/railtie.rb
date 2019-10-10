module Boxable
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/boxable.rake'
    end
  end
end