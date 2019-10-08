require 'box/acts_as_boxable'
require 'box/boxable_config'
require 'box/task'
require 'box/task/install'
require 'box/railtie'

require 'box_token'
require 'box_folder'

begin
  YAML::load_file('config/box.yml').each { |k, v| ENV[k] = v }
rescue Errno::ENOENT
  puts "No box config file found. Try running rake box:install."
end

module Box
end