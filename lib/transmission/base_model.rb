# frozen_string_literal: true

module Transmission
  class BaseModel
    @@config = Transmission::Configuration.config.mongo
    attr_reader :client

    def initialize()
      Mongo::Logger.level = eval(@@config["log_level"])
      @client ||= connect_db
    end

    def self.config
      @@config
    end

    def config
      @@config
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
        adress   =  @@config['adress']
        port     =  @@config['port']
        database =  'transmission'
        client   = Mongo::Client.new(["#{adress}:#{port}"],
                                   database: database,
                                   server_selection_timeout: 5,
                                   :write => {:w => 0, :j => false}) #setto la modalità unacknowledged
        client.database_names
        client
      rescue Mongo::Error::NoServerAvailable => e
        puts 'Cannot connect to the server'
        # Error.report_error('Cannot connect to the server')
      end
    end

  end
end
