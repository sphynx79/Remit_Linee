module Transmission
  class Configuration
    class << self
      attr_accessor :env

      def call(env)
        self.env = env
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

      def config
        read_config
        # SITE          = config_url.site
      end

      def read_config
        y = YAML.load_file config_path
        s = OpenStruct.new
        y.each do |k, v|
          k = k.to_s if !k.respond_to?(:to_sym) && k.respond_to?(:to_s)
          s.send("#{k}=".to_sym, v)
        end
        return s
      end

      def config_path
        File.join(__dir__,"../../config/config.yml")
      end


    end
  end
end






