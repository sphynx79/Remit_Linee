# frozen_string_literal: true

require 'oxcelix'
require 'ap'
require 'resonad'
require 'pry'
require 'hirb'
require 'mongo'

extend Hirb::Console
Hirb.enable(width: 200, height: 500, formatter: false)

DATASET_PATH = 'Dataset.xlsx'

class Dataset
  attr_accessor :sheet, :header, :values
  def initialize
    @values = []
  end

  def open
    @sheet = Oxcelix::Workbook.new(DATASET_PATH, include: ['LINK IT'], copymerge: true).sheets[0]
    result = parse_header
    if result.failure?
      raise result.error
    end
    Resonad.Success(@sheet)
  rescue => error
    Resonad.Failure(error)
  end

  #
  # Mi legge il dataset e mi mette i valori dentro @value
  #
  def read
    @sheet.drop(@sheet.column_size).each_slice(@sheet.column_size) do |row|
      r = {}
      @header.each do |k, v|
        begin
          r[k.to_sym] = row[v].value
        rescue
          r[k.to_sym] = ''
        end
      end
      @values << r
    end
    Resonad.Success(@values)
  rescue => error
    Resonad.Failure(error)
  end

  #
  # Cerca nella prima riga del file excel i campi che mi interessan
  #
  # @example
  #   "paser_header" #=> {voltage: 1, descriptio: 4, country_to: 8}
  #
  # @return [Hash] key campo che mi interessa e valore l'index in cui si trova
  #
  def parse_header
    @header = {}
    field  = %w[voltage description country_from country_to from to location_from location_to type_from type_to]
    field.map do |f|
      @header[f] = seach_column_index(f)
    end
    Resonad.Success(@header)
  rescue => error
    Resonad.Failure(error)
  end

  #
  # Cerca l'index nell'header l'index in cui si trova il mio field
  #
  # @param field [String]
  #
  # @return [Integer]
  #
  def seach_column_index(field)
    i = 0
    while i < @sheet.column_size
      break if @sheet[0, i].value == field
      i += 1
    end
    i
  end

end

MONGO_ADRESS = '127.0.0.1'
MONGO_PORT   = '27017'
MONGO_DB     = 'transmission'
Mongo::Logger.logger.level = ::Logger::FATAL

class Database
  attr_accessor :client, :docs

  def initialize
    @client            = connect_db
    @coll_transmission = @client[:transmission]
  end

  #
  # Si Connette al server
  #
  # @raise [Mongo::Error::NoServerAvailable] se non riesce a connettersi
  #
  # @note write => 0 nessun acknowledged (pero quando vado fare update o scritture non ho nessun risultato)
  #       write => 1 restituisce un acknowledged (quindi quando faccio update o scritture mi dice il numero di documenti scritti)
  #
  # @return [Mongo::Client]
  #
  def connect_db
    begin
      @client = Mongo::Client.new(["#{MONGO_ADRESS}:#{MONGO_PORT}"],
                                  database: MONGO_DB,
                                  server_selection_timeout: 5,
                                  :write => {:w => 0, :j => false}) #setto la modalità unacknowledged
      @client.database_names
      @client
    rescue Mongo::Error::NoServerAvailable => e
      Error.report_error('Cannot connect to the server')
    end
  end


  def make_docs(values)
    @docs = []
    values.each do |row|
      from = (row[:from].split ",").map &:to_f
      to   = (row[:to].split ",").map &:to_f
      name = "#{row[:voltage].strip} #{row[:location_from].strip} #{row[:location_to].strip}"
      docs << {type: "Feature",
               properties: {
                 name:          name,
                 description:   row[:description],
                 country_from:  row[:country_from],
                 country_to:    row[:country_to],
                 location_from: row[:location_from],
                 location_to:   row[:location_to],
                 type_from:     row[:type_from],
                 type_to:       row[:type_to],
                 voltage:       row[:voltage]
               },
               geometry: {
                 type: "LineString",
                 coordinates: [from, to]
               }
      }
    end
  end

  def insert_docs_db
    @coll_transmission.insert_many(@docs)
  end


end

@dataset = Dataset.new
@dataset.open
@dataset.read
@dataset.values
@databse = Database.new
@databse.make_docs(@dataset.values)
@databse.insert_docs_db
