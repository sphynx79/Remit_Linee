#!/usr/bin/env ruby
# warn_indent: true
# frozen_string_literal: true

ruby '>= 3.1'

source 'https://rubygems.org'

# le gemme 0.x sono fissate alla serie patch (~> X.Y.Z): prima della 1.0
# anche una minor puo' introdurre breaking change, quindi accetto solo fix
gem 'amatch', '~> 0.7.0'
gem 'awesome_print', '~> 1.9'
# usata direttamente (unique_id in archivia_controller): da Ruby 3.4 non e' piu' default gem
gem 'base64', '~> 0.3.0'
gem 'csv', '~> 3.3'
gem 'dry-inflector', '~> 1.0'
gem 'elixirize', '~> 0.5.0'
gem 'functional-light-service', '~> 6.1'
gem 'fuzzy_match', '~> 2.1'
gem 'gli', '~> 2.22'
gem 'memoist', '~> 0.16.2'
gem 'mongo', '~> 2.21'
gem 'net-smtp', '~> 0.5.1', require: false
gem 'nokogiri', '~> 1.18'
gem 'oj', '~> 3.16'
gem 'rubyXL', '~> 3.4'
gem 'rufus-scheduler', '~> 3.9', require: false
gem 'simple_xlsx_reader', '~> 5.0'
gem 'tty-prompt', '~> 0.23.1'
gem 'tzinfo', '~> 2.0'
gem 'tzinfo-data', '~> 1.2025'
gem 'watir', '~> 7.3'
gem 'yell', '~> 2.2'

group :development, :test do
  # reline (usata da pry su Windows) richiede fiddle, che da Ruby 4
  # non e' piu' una default gem
  gem 'fiddle', '~> 1.1'
  gem 'pry', '~> 0.16.0'
  gem 'pry-byebug', '~> 3.11'
  gem 'rubocop', '~> 1.75', require: false
  gem 'rubocop-performance', '~> 1.20', require: false
end
