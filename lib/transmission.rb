$:.unshift File.expand_path(File.dirname(__FILE__)) 

module Transmission
  autoload :Config,         'transmission/config'
  autoload :Initialization, 'transmission/initialization'
  autoload :Application,    'transmission/application'
  autoload :BaseController, 'transmission/base_controller'
  autoload :BaseModel,      'transmission/base_model'
  autoload :BaseMail,       'transmission/base_mail'
end
