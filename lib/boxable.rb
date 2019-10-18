require 'boxable/acts_as_boxable'
require 'boxable/bound_to_boxable'
require 'boxable/boxable_config'
require 'boxable/after_create_attachment'
require 'boxable/task'
require 'boxable/helper'
require 'boxable/railtie'
require 'boxable/error'

require 'box_token'
require 'box_tokens_controller'
require 'box_folder'
require 'box_file'

module Boxable
  mattr_accessor :root
  @@root = '/'

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
