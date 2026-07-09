#!/usr/bin/env ruby
# warn_indent: true
# frozen_string_literal: true

require 'erb'
require 'yaml'

module Transmission
  # Sostituisce la gem settingslogic (non mantenuta, incompatibile con
  # Psych 4 / Ruby 3.1+ per gli alias YAML). Stessa API: accesso annidato
  # con metodi (Config.database.name) e namespace scelto via DSL di classe.
  class Settings < Hash
    class MissingSetting < StandardError; end

    class << self
      def source(file_path = nil)
        @source = file_path if file_path
        @source
      end

      def namespace(value = nil)
        @namespace = value if value
        @namespace
      end

      def instance
        @instance ||= begin
          yaml = ERB.new(File.read(source)).result
          data = YAML.safe_load(yaml, aliases: true)
          data = data.fetch(namespace) if namespace
          new(data)
        end
      end

      def reload!
        @instance = nil
        instance
      end

      def method_missing(name, *args, &block)
        instance.public_send(name, *args, &block)
      end

      def respond_to_missing?(name, include_all = false)
        instance.respond_to?(name, include_all) || super
      end
    end

    def initialize(hash = {})
      super()
      hash.each { |k, v| self[k.to_s] = v.is_a?(Hash) ? self.class.new(v) : v }
    end

    def method_missing(name, *_args)
      key = name.to_s
      raise MissingSetting, "Missing setting '#{key}'" unless key?(key)

      self[key]
    end

    def respond_to_missing?(name, _include_all = false)
      key?(name.to_s) || super
    end
  end
end
