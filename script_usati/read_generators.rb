require 'ap'
require 'pry'
require 'mongo'

MONGO_ADRESS = '127.0.0.1'
MONGO_PORT   = '27017'
MONGO_DB     = 'transmission'
Mongo::Logger.logger.level = ::Logger::FATAL

class Database
  attr_accessor :client, :docs

  def initialize
    @client        = connect_db
    @coll_centrali = @client[:centrali]
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

  def insert_docs_db(docs)
    @coll_centrali.insert_many(docs)
  end


end

@docs = []
f = File.readlines('generators.csv').each do |line|
  a = line.sub(/'[\D\w]*',/,"").strip
  a = a.split ","
  generator_id = a[0]
  bus_id       = a[1]
  symbol       = a[2]
  capacity     = a[3]
  geometry     = a[4]
  lo,la      = geometry.sub("POINT","").sub("(","").sub(")","").split " "

  hstore = (line.match /'[\D\w]*'/)[0]
  hstore = hstore.gsub("'","").gsub("\"","")
  tags = {}
  hstore.split(",").each do |x|
    k,v  = x.split "=>"
    tags[k] = v
  end
  @docs << {type: "Feature",
             properties: {
                 country:       tags["country"],
                 name:          tags[" name_all"],
                 capacity:      capacity,
                 symbol:        symbol,
                 mb_symbol:     tags[" mb_symbol"],
               },
                geometry: {
                 type: "Point",
                 coordinates: [lo.to_f, la.to_f]
               }
  }

end
@databse = Database.new
@databse.insert_docs_db(@docs)
