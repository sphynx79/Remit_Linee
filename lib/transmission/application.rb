module Transmission
  class Application
    class << self
      attr_accessor :env

      def call(env)
        self.env = env
        dispatch
      end

      def dispatch
        controller.new(env).public_send(env[:action])
      end

      def controller
        controller_name = env[:controller].
                          ᐅ(~:capitalize).
                          ᐅ(~:+, 'Controller')

       Object.const_get(controller_name)
      end
    end
  end
end
