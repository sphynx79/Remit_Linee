# frozen_string_literal: true

module Transmission
  class BaseModel

    attr_reader :client

    def initialize()
      Mongo::Logger.level = eval(Transmission::Config.database.log_level)
      @client ||= connect_db
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
        adress   = Transmission::Config.database.adress
        port     = Transmission::Config.database.port
        database = Transmission::Config.database.name
        client   = Mongo::Client.new(["#{adress}:#{port}"],
                                   database: database,
                                   server_selection_timeout: 5,
                                   :write => {:w => 1, :j => false}) #@todo vedere se mettere w => 0, setto la modalità unacknowledged
        client.database_names
        client
      rescue Mongo::Error::NoServerAvailable => e
        puts 'Cannot connect to the server:'
        puts '1) Controllare che il server mongodb sia avviato'
        puts '2) Controllare in config che IP, PORTA, NOME database siano corretti'
        exit!
        # Error.report_error('Cannot connect to the server')
      end
    end

  end
end
