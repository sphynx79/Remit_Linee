# frozen_string_literal: true
# encoding: utf-8

$LOAD_PATH.unshift '.'

require 'active_support/core_ext/string/inflections'
require 'pathname'
require 'gli'
require 'mongo'
require 'memoist'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'elixirize'
require 'simple_xlsx_reader'
# require 'pry'
require 'fuzzy_match'
require 'amatch'
require 'settingslogic'
require 'yell'
require 'deterministic'
# @todo: vedere se lasciare maybe se mi serve
require 'deterministic/maybe'
require 'lib/transmission'
require 'tty-prompt'
require 'net/smtp'
require 'rubyXL'
require 'open3'
require 'ap'
# require 'oj'
require 'json'
require 'csv'
require 'tzinfo'
require 'watir'
# require 'pretty_backtrace'
#
# PrettyBacktrace.enable
# PrettyBacktrace.multi_line = true

include Deterministic::Prelude
include Deterministic::Prelude::Option

FuzzyMatch.engine = :amatch

APP_ROOT    = Pathname.new(File.expand_path('.', __dir__))
APP_NAME    = APP_ROOT.parent.basename.to_s
APP_VERSION = "1"
TZ = TZInfo::Timezone.get('Europe/Rome')
ENV["TZ"] = "UTC"

ENV['GLI_DEBUG'] = 'false'

module Transmission
  include GLI::App
  extend self

  program_desc 'Programma per scaricare la remit delle linee terna'
  version APP_VERSION
  subcommand_option_handling :normal
  arguments :strict
  sort_help :manually
  wrap_help_text :one_line

  desc 'Setto se lanciarlo in verbose mode'
  switch %i[v verbose]

  desc 'Interfaccia da usare [gui, cli, scheduler]'
  default_value 'cli'
  flag %i[i interface], required: false

  desc 'Enviroment da usare [production, development]'
  default_value 'development'
  flag %i[e enviroment], required: false, :must_match => ["production", "development"]

  desc 'Scarica da internet i file della remit'
  long_desc %{Si connette al sito di terna e scarica in locale il file remit delle linee}
  command :download do |c|
    c.action do 
      Transmission::Application.call(@env)
    end
  end

  desc 'Carica il file della remit a db'
  command :archivia do |c|
    c.action do 
      Transmission::Application.call(@env)
    end
  end

  desc 'Esporta anagrafica da MapBox'
  long_desc %(Esporta anagrafica presente in MapBox e la traforma in csv)
  command :anagrafica do |c|
    c.desc 'volt da esportare (380, 220)'
    c.flag %i[v volt], required: true, type: String
    c.action do 
      Transmission::Application.call(@env)
    end
  end

  pre do |global, command, options|
    if global[:enviroment] == "development"
      set_development
    end
    # @todo: vedere se usare questa variabile o trovare modo piu elegante
    $INTERFACE = global[:interface]
    init_log(global[:verbose])
    set_env(command, global, options)
    Transmission::Initialization.call()
    true
  end

  on_error do |exception|
    msg = exception.message
    case exception
    when GLI::UnknownGlobalArgument
      if msg =~ /-e\s|-enviroment/
        puts "Devi specificare l'enviroment:"
        puts "    -e           [production, development]"
        puts "    --enviroment [production, development]"
      end
      false # skip GLI's error handling
    else
      true # use GLI's default error handling
    end
  end

  def init_log(verbose)
    level = verbose ? "debug" : "info"
    if $INTERFACE == "scheduler"
      Yell.new(name: Object, format: false) do |l|
        l.adapter STDERR, colors: true, level: 'gte.fatal'
      end
    else
      Yell.new(name: Object, format: false) do |l|
        l.adapter STDOUT, level: "gte.#{level} lte.error"
        l.adapter STDERR, level: 'gte.fatal'
      end
    end
    Yell.new(name: 'scheduler', format: false) do |l|
      l.adapter STDOUT, colors: false, level: 'at.warn'
      l.adapter STDERR, colors: false, level: 'at.error'
        # l.adapter :file, 'log/application.log', level: 'at.fatal', format: false
    end
    # Yell.new(name: 'scheduler', format: Yell.format('%d: %m', '%d-%m-%Y %H:%M')) do |l|
    #   l.adapter STDOUT, colors: false, level: 'at.warn'
    #   l.adapter STDERR, colors: false, level: 'at.error'
    #   l.adapter :file, 'log/application.log', level: 'at.fatal', format: false
    # end
    # Yell.new(name: 'verbose', format: false) do |l|
    #   l.adapter STDOUT, colors: false, level: 'at.info'
    # end
    #
    Object.send :include, Yell::Loggable
  end

  def set_development
    # @todo: vedere se lasciare ENV['GLI_DEBUG'] = true
    ENV['GLI_DEBUG'] = 'true'
    require 'pry'
  end

  def set_env(command, global, options)
    ENV['APP_ENV'] ||= global[:enviroment]
    action     = "start"
    controller = command.name.to_s
    @env = {controller:       controller,
            action:           action,
            command_options:  options,
            }
  end

  # Controllo se lo sto lanciandi come programma
  # oppure il file è stato usato come require
  if __FILE__ == $0
   exit run(ARGV)
  end

end


