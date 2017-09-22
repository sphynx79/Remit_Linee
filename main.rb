# frozen_string_literal: true

$LOAD_PATH.unshift '.'

RubyVM::InstructionSequence.compile_option = { tailcall_optimization: true, trace_instruction: false }

require 'active_support/core_ext/string/inflections'
require 'pathname'
require 'gli'
require 'mongo'
require 'memoist'
require 'nokogiri'
require 'open-uri'
require 'elixirize'
require 'simple_xlsx_reader'
require 'pry'
require 'fuzzy_match'
require 'amatch'
require 'settingslogic'
require 'lib/transmission'

APP_ROOT    = Pathname.new(File.expand_path('.', __dir__))
APP_NAME    = APP_ROOT.basename.to_s
APP_VERSION = "1"

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

  desc 'Log level [debug, info, warn, error, fatal]'
  default_value 'info'
  flag %i[l log], required: false

  desc 'Interfaccia da usare [gui, cli, scheluder]'
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

  pre do |global, command, options|
    if global[:enviroment] == "development"
      set_development
    end
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

  def init_log(level)
    # Yell.new(name: Object, format: false) do |l|
    #   l.adapter STDOUT, colors: true, level: "gte.#{level} lt.warn"
    #   l.adapter STDERR, colors: true, level: 'error', format: false
    # end
    # Yell.new(name: 'scheduler', format: Yell.format('%d: %m', '%d-%m-%Y %H:%M')) do |l|
    #   l.adapter STDOUT, colors: false, level: 'at.warn'
    #   l.adapter STDERR, colors: false, level: 'at.error'
    #   l.adapter :file, 'log/application.log', level: 'at.fatal', format: false
    # end
    # Yell.new(name: 'verbose', format: false) do |l|
    #   l.adapter STDOUT, colors: false, level: 'at.info'
    # end
    #
    # Object.send :include, Yell::Loggable
  end

  def set_trace_point
    # trace = TracePoint.new(:call) do |tp|
    #   tp.disable
    #   path = tp.path
    #   if (path =~ /Remit/) && (path !~ /rblcl/i) && (path !~ /ruby/i)
    #     parameters = eval("method(:#{tp.method_id}).parameters", tp.binding)
    #     parameters.map! do |_, arg|
    #       if tp.binding.local_variable_defined?(arg)
    #         "#{arg} = #{tp.binding.local_variable_get(arg)}"
    #       end
    #     end.join(', ')
    #     puts "#{'*' * 40}CALL#{'*' * 40}".blue
    #     puts "File: #{tp.path.split('/')[-2..-1].join('/')}:#{tp.lineno}".green
    #     puts "Class: #{tp.defined_class}".green
    #     puts "Method: #{tp.method_id}".green
    #     puts "Params: #{parameters * ','}".green
    #   end
    #   tp.enable
    # end
    # trace.enable
  end

  def init_verbose(verbose)
    # $VERBOSE_MODE = verbose
  end

  def set_development
    ENV['GLI_DEBUG'] = 'true'
    require 'ap'
    require 'pry'
  end

  def set_env(command, global, options)
    ENV['APP_ENV'] ||= global[:enviroment]
    action     = "start"
    controller = command.name.to_s
    @env = {controller:       controller,
            action:           action,
            global_options:   global,
            command_options:  options,
            }
  end

  exit run(ARGV)

end

