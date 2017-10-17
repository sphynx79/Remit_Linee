module Transmission
  class Initialization
    class << self

      def call()
        load_file
      end

      def load_file
        load_model
        load_controller
        load_view
        load_helper
      end

      def load_model
        Dir[APP_ROOT.join('app', 'models', '*.rb')].each do |model_file|
          filename = File.basename(model_file).gsub('.rb', '')
          Object.autoload ActiveSupport::Inflector.camelize(filename), model_file
        end
      end

      def load_controller
        Dir[APP_ROOT.join('app', 'controllers', '*.rb')].each do |controller_file|
         filename = File.basename(controller_file).gsub('.rb', '')
         Object.autoload ActiveSupport::Inflector.camelize(filename), controller_file
        end
      end

      def load_helper
        Dir[APP_ROOT.join('app', 'helper', '*.rb')].each do |helper_file|
          filename = File.basename(helper_file).gsub('.rb', '')
           Object.autoload ActiveSupport::Inflector.camelize(filename), helper_file
        end
      end

      def load_view
        # Dir[APP_ROOT.join('app', 'views', 'layout', '*.rb')].each do |layout_file|
        #   filename = File.basename(layout_file).gsub('.rb', '')
        #   autoload ActiveSupport::Inflector.camelize(filename), layout_file
        # end
      end

    end
  end
end






