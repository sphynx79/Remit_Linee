# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'
require 'pathname'
require 'gli'

APP_ROOT = Pathname.new(File.expand_path('..', __dir__))
APP_NAME = APP_ROOT.basename.to_s

# carico model
Dir[APP_ROOT.join('app', 'models', '*.rb')].each do |model_file|
  filename = File.basename(model_file).gsub('.rb', '')
  autoload ActiveSupport::Inflector.camelize(filename), model_file
end

# carico controller 
Dir[APP_ROOT.join('app', 'controllers', '*.rb')].each do |controller_file|
  filename = File.basename(controller_file).gsub('.rb', '')
  autoload ActiveSupport::Inflector.camelize(filename), controller_file
end

# carico view
Dir[APP_ROOT.join('app', 'views', '*.rb')].each do |view_file|
  filename = File.basename(view_file).gsub('.rb', '')
  autoload ActiveSupport::Inflector.camelize(filename), view_file
end

# carico layout
Dir[APP_ROOT.join('app', 'views', 'layout', '*.rb')].each do |layout_file|
  filename = File.basename(layout_file).gsub('.rb', '')
  autoload ActiveSupport::Inflector.camelize(filename), layout_file
end

# carico helper
Dir[APP_ROOT.join('app', 'helper', '*.rb')].each do |helper_file|
  filename = File.basename(helper_file).gsub('.rb', '')
  autoload ActiveSupport::Inflector.camelize(filename), helper_file
end

# autoload :Gui, APP_ROOT.join('Gui.rb')

#se voglio usare un file config 
#config_path = Config.read_config('path')
#DOWNLOAD_PATH       = File.expand_path(config_path.download,       File.dirname(__dir__))
#CONVERSIONE_PATH    = File.expand_path(config_path.conversione,    File.dirname(__dir__))
#ANAGRAFICA_PATH     = File.expand_path(config_path.anagrafica,     File.dirname(__dir__))
#ANAGRAFICA_CSV_PATH = File.expand_path(config_path.anagrafica_csv, File.dirname(__dir__))

# crea la struttura delle directory se non esistono
#FileUtils.mkdir_p DOWNLOAD_PATH + '/Archivio'

# mongo_config = Config.read_config('mongo')
# MONGO_DB     = mongo_config.db
# MONGO_ADRESS = mongo_config.adress
# MONGO_PORT   = mongo_config.ip
