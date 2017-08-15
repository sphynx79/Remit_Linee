# frozen_string_literal: true

require_relative 'config/application'

ENV['GLI_DEBUG'] = 'false'

module Transmission
  include GLI::App
  extend self

  program_desc 'Programma per gestire scaricare la remit delle linee terna'
  version '1'

  
  
end
