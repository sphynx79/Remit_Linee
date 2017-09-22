$:.unshift File.expand_path(File.dirname(__FILE__)) 

module Transmission
  autoload :Configuration, 'transmission/configuration'
  autoload :Application, 'transmission/application'
  autoload :BaseController, 'transmission/base_controller'
  autoload :BaseModel, 'transmission/base_model'
end
