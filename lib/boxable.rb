require 'boxable/acts_as_boxable'
require 'boxable/boxable_config'
require 'boxable/task'
require 'boxable/task/install'
require 'boxable/helper'
require 'boxable/railtie'
require 'boxable/error'

require 'box_token'
require 'box_folder'
require 'box_file'
require 'box_file_collection'

begin
  YAML::load_file(Boxable::Helper.config_path).each { |k, v| ENV[k] = v }
rescue Errno::ENOENT
  puts 'No box config file found. Try running rake boxable:install.'
end

module Boxable
end