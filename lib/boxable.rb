require 'boxable/acts_as_boxable'
require 'boxable/boxable_config'
require 'boxable/after_create_attachment'
require 'boxable/task'
require 'boxable/task/install'
require 'boxable/helper'
require 'boxable/railtie'
require 'boxable/error'

require 'box_token'
require 'box_tokens_controller'
require 'box_folder'
require 'box_file'
require 'box_file_collection'

begin
  YAML::load_file(Boxable::Helper.config_path).each { |k, v| ENV[k] = v }
rescue Errno::ENOENT
  puts 'No box config file found. Try running rake boxable:install.'
end

module Boxable
  class Engine < ::Rails::Engine

    config.before_initialize do
      if config.action_view.javascript_expansions
        config.action_view.javascript_expansions[:boxable] = %w(boxable)
      end
    end

    # configure our plugin on boot
    #initializer "cocoon.initialize" do |app|
    #  ActiveSupport.on_load :action_view do
    #    ActionView::Base.send :include, Cocoon::ViewHelpers
    #  end
    #end

  end
end
