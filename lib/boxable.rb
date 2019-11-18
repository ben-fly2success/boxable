require 'boxable/acts_as_boxable'
require 'boxable/boxable_config'
require 'boxable/after_create_attachment'
require 'boxable/task'
require 'boxable/helper'
require 'boxable/railtie'
require 'boxable/error'
require 'boxable/instance_base'

require 'box_token'
require 'box_tokens_controller'
require 'box_folder'
require 'box_file'
require 'box_file_version'

module Boxable
  mattr_accessor :root
  @@root = '/'

  mattr_accessor :private_key
  mattr_accessor :private_key_password
  mattr_accessor :public_key_id
  mattr_accessor :enterprise_id
  mattr_accessor :client_id
  mattr_accessor :client_secret

  def self.setup
    yield self
  end

  class Engine < ::Rails::Engine

    config.before_initialize do
      if config.action_view.javascript_expansions
        config.action_view.javascript_expansions[:boxable] = %w(boxable)
      end
    end

    # configure our plugin on boot
    #initializer "boxable.initialize" do |app|
    #  ActiveSupport.on_load :action_view do
    #    ActionView::Base.send :include, Boxable::ViewHelpers
    #  end
    #end

  end
end
