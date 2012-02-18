require 'focused_controller/version'
require 'focused_controller/route'

require 'active_support/concern'
require 'active_support/core_ext/string/conversions'

module FocusedController
  extend ActiveSupport::Concern

  module ClassMethods
    def controller_path
      @focused_controller_path ||= name.sub(/\:\:[^\:]+$/, '').sub(/Controller$/, '').underscore
    end
  end

  def action_name
    self.class.name.demodulize.underscore.sub(/_controller$/, '')
  end

  def method_for_action(name)
    'run'
  end
end
