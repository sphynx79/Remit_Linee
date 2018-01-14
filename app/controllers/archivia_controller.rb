# frozen_string_literal: true
# encoding: utf-8

# STDOUT.sync = true

class NoArchivate
  attr_accessor :match, :no_match
  attr_reader :file

  def initialize(file)
    @file     = file
    @match    = []
    @no_match = []
  end

end

Decision = Deterministic::enum {
  Si()
  No()
  Forse(:scheduler)
}

class ArchiviaController < Transmission::BaseController
  extend Memoist
  include SyncHelper
  include ReportHelper

  attr_reader :linee_380

  def start
    begin
      @linee_380 = transmission_380
      exit_if_not_files

      archivia
    rescue => e
      logger.fatal(e.message)
      logger.fatal(e.backtrace.select { |v| v =~ /#{APP_NAME}/ }[0])
    end
  end

  private

  #
  # Controllo se ho almeno un file da leggere
  # se non ci sono file esce
  #
  def exit_if_not_files
    if lista_file.empty?
      Yell['scheduler'].warn("Nessun file da archiviare")
      (exit! 2)
    end
  end

  #
  # Avvia il processo di archiviazione
  #
  def archivia
    def in_sequence_archivia
      lista_file.map do |file|
        @no_archiviate = NoArchivate.new(file)
        @bulk_op       = []
        in_sequence do
          get(:remit)              { leggi_remit(file)                                          }
          and_then                 { scan_for_archive(remit)                                    }
          and_then                 { write_bulk_op                                              }
          get(:match)              { get_match                                                  }
          get(:match_path)         { make_file_xlsx(file, match: match)                         }
          get(:nomatch)            { get_nomatch                                                }
          get(:nomatch_path)       { make_file_xlsx(file, nomatch: nomatch)                     }
          and_then                 { make_report(match_path, match, nomatch_path, nomatch)      }
          and_then                 { sposta_file(file)                                          }
          and_then                 { sincronizzazione                                           }
          and_yield                { Success("Archiviata #{file.split("/").last} con successo") }
        end
      end
    end

    #
    # Legge il file della remit
    #
    # @param file  [String] "./excel_file//remit_YYYY_M_D.xlsx"
    #
    # @note
    #  esegue sequenza
    #   - apre file xlsx
    #   - prende lo sheet
    #   - prende la data di update
    #   - prende i valori dello sheet
    #  Se termina con Success => ritorna un array di hash, dove ogni riga di remit è un elemento del mio array
    #  Se termina con False   => uscita inaspettata ritorna l'eccezione
    #
    # @return [Success(Array<Hash>), Failure(Exception)]
    #
    def leggi_remit(file)
      def in_sequence_leggi_remit(file)
        in_sequence do
          get(:xlsx)      { open_xlsx(file)            }
          get(:sheet)     { get_sheet(xlsx)            }
          get(:dt_upd)    { get_dt_upd(file)           }
          get(:values)    { get_values(sheet, dt_upd)  }
          and_yield       { Success(values)            }
        end
      end

      #
      # Apre il file della remit
      #
      # @return[SimpleXlsxReader::Document]
      #
      def open_xlsx(file)
        begin
          xlsx = SimpleXlsxReader.open(file)
          Success(xlsx)
        rescue => e
          file_path = File.expand_path(file, APP_ROOT)
          message = <<~HEREDOC
            Non sono riuscito ad aprire il file #{file_path}
            Scaricarlo a mano dal sito e controllare che non sia corrotto
          HEREDOC
          Failure(message)
        end
      end

      #
      # Prende le righe dal foglio della remit
      #
      # @note
      # - elimina le prime 5 righe
      # - applica un filtro per prendere solo i valori che mi servono(LIN e 400 kV)
      #
      # @return [Array<Array>]
      #
      def get_sheet(file)
        filter = ->(row) {row[1] == "LIN" &&  row[2] == "400 kV"}
        try! do
          file.
            ᐅ(~:sheets).
            ᐅ(~:first).
            ᐅ(~:rows).
            ᐅ(~:drop, 5).
            ᐅ(~:keep_if, &filter)
        end
      end

      #
      # Trova la data che è stata creato, la estrae dal nome del file
      #
      # @return[DateTime]
      #
      def get_dt_upd(file)
        try! do
          # to_datetime =  ->(string) { DateTime.strptime(string,"%Y_%m_%d") }
          file.
            ᐅ(~:split, '/').
            ᐅ(~:last).
            ᐅ(~:gsub, /remit_|.xlsx|_adjust/i, "").
            ᐅ(DateTime.method(:strptime), "%Y_%m_%d")
        end
      end

      #
      # Prende i valori che mi interessano presenti nello sheet
      #
      # @param sheet  [Array]
      # @param dt_upd [DateTime]
      #
      # @return [Array<Hash>] ogni riga e un elemento del mio array
      #
      def get_values(sheet, dt_upd)
        try! do
          sheet.map do |row|
            nome       = row[0]
            volt       = row[2]
            start_date = (row[3].is_a? String) ? Date.parse(row[3]) : row[3]
            start_time = (row[4].is_a? String) ? Time.parse(row[4]) : row[4]
            end_date   = (row[5].is_a? String) ? Date.parse(row[5]) : row[5]
            end_time   = (row[6].is_a? String) ? Time.parse(row[6]) : row[6]
            reason     = row[8]
            decision   = row[10]
            start_dt   = to_datetime(start_date, start_time)
            end_dt     = to_datetime(end_date, end_time)
            {nome: nome, volt: volt, dt_upd: dt_upd, start_dt: start_dt, end_dt: end_dt, reason: reason, decision: decision}
          end
        end
      end

      in_sequence_leggi_remit(file)
    end #END leggi_remit

    #
    # Avvia il processo di scansione delle remit che posso archiviare
    #
    # @param remit_terna [Array<Hash>)] | ogni riga di remit e un elemento del mio array
    #
    # @note uscita inaspettata mi viene segnalato con un logger.warn
    #
    # sequenza:
    # - cerca id linea in transmission
    # - restitiusce id trovato oppure avvia la ricerca di un possibile id
    # - crea id univo per questa remita
    # - controlla se esiste questa remit nel DB remit
    # - crea il doc da inserire nel DB remit
    # - lo accoda in una variabile per successivo inserimento in modalità bulk
    #
    def scan_for_archive(remit_terna)
      def sequence_scan_for_archive(remit_terna)
        # @todo: vedere se posso eliminare questo try
        remit_terna.each do |row|
          row.freeze
          nome_terna = row[:nome]

          result = in_sequence do
            get(:id_trovato)   { transmission_id(nome_terna)                           }
            get(:id)           { id_trovato ? Success(id_trovato) : possibili_id(row)  }
            get(:ui)           { unique_id(row)                                        }
            and_then           { check_exist_in_db(ui)                                 }
            get(:doc)          { make_doc(row, id, ui)                                 }
            and_then           { insert_in_bulk_op(doc)                                }
            and_yield          { Success("Archiviata con successo")                    }
          end

          logger.warn(result.to_s) if (result.failure?)

          logger.info "\n"+ "#"*80 + "\n"
        end
        Success(0)
      end

      #
      # Cerca nella collezione transmission il nome della linea
      #
      # @param nome_terna [String]
      #
      # Success(nil) => @return [Success(nil)]            | non ha trovato nessuna linea
      # Success(id)  => @return [Success(BSON::ObjectId)] | id della linea che ha trovato
      # Failure(e)   => @return [Failure(Exception)]      | uscita inaspettata ritorna l'eccezione
      #
      def transmission_id(nome_terna)
        try! do

          logger.info "Cerco per #{nome_terna} l'id della linea nel db transmission"
          
          doc = linee_380.lazy.select{|f| f[:properties][:nome_terna].include?(nome_terna) }.first

          if doc.nil?
            logger.warn "Per #{nome_terna} non ho trovato nessun id".red
            Success(nil)
          else
            id = doc[:id]
            logger.info "Trovato per #{nome_terna} => #{id}".green
            Success(id)
          end
        end
      end

      #
      # Cerca nel db transmission le linee che potrebbere matchare con il nome
      #
      # @param row [Hash] hash che rappresenta il documento che dovrebbe essere iserito a db
      #
      # Success(id_transmission) => @return [Success(BSON::ObjectId)] | id della linea che ha trovato
      # Failure(messagio)        => @return [Failure(String)]         | nessuno id trovato restituisce un messaggio
      # Failure(e)               => @return [Failure(Exception)]      | uscita inaspettata ritorna l'eccezione
      #
      def possibili_id(row)
        logger.info "Cerco nel db i possibili id che possono corrispondere al nome"

        def sequence_possibili_id(row)
          nome = row[:nome]
          row  = row.dup

          in_sequence do
            get(:id_terna)        { get_id_terna(nome)                                           }
            get(:nome_clean)      { get_nome_clean(nome)                                         }
            observe               { logger.info "nome linea:      #{nome}".rjust(5)              }
            get(:match)           { fuzzy_search_line(id_terna, nome_clean)                      }
            get(:trovato)         { trovato?(match)                                              }
            get(:nome_match)      { trovato ? get_nome(match) : insert_no_match(row)             }
            observe               { logger.info("Trovato a db:    " + nome_match)                }
            get(:row_with_match)  { add_nome_match_to_row(row, nome_match)                       }
            get(:id_transmission) { get_id_transmission(match)                                   }
            get(:decision)        { check_decison(row)                                           }
            let(:scheduler)       { $INTERFACE == "scheduler"                                    }
            get(:type_decion)     { get_type_decision(decision, scheduler)                       }
            let(:action)          { get_action(type_decion)                                      }
            get(:type_decion)     { esegui_action(action, row_with_match, match, nome) }
            and_yield             { Success(id_transmission)                                     }
          end
        end

        def esegui_action(action, row_with_match, match_line, nome)
         case action
          when "salva"        then salva_nome_terna(match_line, nome)
          when "insert_match" then insert_match(row_with_match)
          else
            Failure("Action non eseguibile")
          end
        end

        def get_type_decision(decision, scheduler)
          try! do
            Decision.send(decision, scheduler)
          end
        end

        def get_action(action)
          action.match {
            Si()                        { "salva" }
            No()                        { "insert_match"     }
            Forse(where { s == true })  { |s| "insert_match" }
            Forse(where { s == false }) { |s| salvo_nome_in_db ? "salva" : "insert_match" }
          }
        end

        def get_id_terna(nome)
          id = nome.match(/\d{3}/)
          id = id.nil? ? "" : id[0]
          Success(id.to_s)
        end

        def get_nome_clean(nome)
          try! do
            nome = nome.dup
            nome.downcase!
            nome.sub!("linea 400 kv ", "")
            nome.sub!("linea ", "")
            nome.sub!(/l\s/, "")
            nome.strip!
            nome
          end
        end

        #
        # Utilizza la gemma fuzzymatch per cercare tra tutte le linee che ho in anagrafica
        # il nome che piu assomiglia al nome della linea che sto leggendo
        #
        # @param id_terna [String]
        # @param nome     [String]  | nome della linea che deve cercare
        #
        # @return [Array<Hash>] =>  [{"_id"=>BSON::ObjectId('5957c...'), "properties"=>{"nome"=>"005 nome_linea"}}, score1, score2]
        #
        def fuzzy_search_line(id_terna, nome)
          try! do
            # @todo: ho utilizzato per all_line la memoize vedere se puo dare problemi
            # in caso inserisco una linea e ho la stessa linea nello stesso file
            reader = lambda { |record| record[:properties][:nome]}
            # if nome.match /filisur/
              # binding.pry
            # end

            # fuzzy_match = FuzzyMatch.new(linee_380,:read => reader, :groupings => [/#{id_terna}/], :must_match_grouping => true)
            fuzzy_match = FuzzyMatch.new(linee_380,:read => reader)
            fuzzy_match.find_with_score(nome)
          end
        end

        #
        # Controlla se ha trovato almeno un match w che abbia uno score sufficentemente alto
        #
        #
        # @param match [Array<Hash>]
        #
        # @return [Success(nil), Success(0)] nil se non ha trovato niente o score troppo basso e 0 ha trovato un match
        #
        def trovato?(match)
          if match.nil?
            logger.info "Non trovo nessuna linea"
            Success(nil)
          elsif (match[1] < 0.4) && (match[2] < 0.4)
            logger.info("Trovato: #{match[0].dig("properties","nome")}")
            logger.info("Score troppo basso: #{match[1].to_s} #{match[2].to_s}".red)
            Success(nil)
          else
            Success(0)
          end
        end

        #
        # Imposta nella mia riga la colonna possibile il valore nessuno
        # la accoda nella variabile @no_archiviate
        # e va in Failure per farmi uscire dalla mia sequenza
        #
        def insert_no_match(row)
          row  = row.dup
          row[:possibile_match] = 'nessuno'
          @no_archiviate.no_match << row
          Failure("Questa remit non viene archiviata a DB".red)
        end

        def get_nome(match)
          try!{ match[0].dig(:properties,:nome)}
        end

        #
        # Controlla nell'excel se nella colonna decision cè si o no
        # restituisce sempre un Success(si|no|forse)
        #
        def check_decison(row)
          if row[:decision] == "SI"
            logger.info("Sto leggendo un file adjust")
            logger.info("In decision ho SI")
            Success("Si")
          elsif row[:decision] == "NO"
            logger.info("Sto leggendo un file adjust")
            logger.info("In decision ho NO")
            Success("No")
          else
            Success("Forse")
          end
        end

        #
        # Accoda la mia riga nella variabile @no_archiviatae
        # e va in Failure per farmi uscire dalla mia sequenza
        #
        def insert_match(row)
          @no_archiviate.match << row
          Failure("Questa remit non viene archiviata a DB".red)
        end

        def add_nome_match_to_row(row, nome_match)
          row = row.dup
          row[:possibile_match] = nome_match
          Success(row)
        end

        def get_id_transmission(match)
          try!{ match[0][:id] }
        end

        #
        # Salva il nome che ha trovato nel DB transmission
        # e restitusce Success("ok")
        #
        def salva_nome_terna(match_line, nome)
            logger.debug "Salvo il nome_terna a db"

            # doc_id_transmission   = coll_transmission.find({_id: id_transmission}).limit(1)
            array_nome_terna_size = match_line[0][:properties][:nome_terna].size

            logger.info "Attenzione questa linee ha gia #{array_nome_terna_size} nomi" if array_nome_terna_size > 0
            id   = match_line[0][:id]
            match_line[0][:properties][:nome_terna].push(nome)

            json =  match_line[0].to_json

            url  = "https://api.mapbox.com/datasets/v1/browserino/cjcb6ahdv0daq2xnwfxp96z9t/features/#{id}?access_token=sk.eyJ1IjoiYnJvd3NlcmlubyIsImEiOiJjamEzdjBxOGM5Nm85MzNxdG9mOTdnaDQ0In0.tMMxfE2W6-WCYIRzBmCVKg"
            
            uri  = URI.parse(url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Put.new(uri)
            request.body = json
            request.set_content_type("application/json")
            response = http.request(request)
            if response.kind_of? Net::HTTPSuccess
              logger.info "nome_terna #{nome} salvato nel db"
              Success("Salvato nome terna a db")
            else
              Failure("Errore nel salvataggio nome linea a db")
            end
        end

        # Mi chiede se voglio salvare la linea a db
        #
        def salvo_nome_in_db
          prompt = TTY::Prompt.new
          prompt.yes?('Vuoi salvare il nome della linea?'.green)
        end

        sequence_possibili_id(row)
      end

      #
      # Concatena dt_upd start_dt end_dt nome, e mi crea un id univoco in base64
      #
      # @param row  [Hash] hash che rappresenta il documento che dovrebbe essere iserito a db
      #
      # @return [String]
      #
      def unique_id(row)
        try! do
          dt_upd     = row[:dt_upd].strftime("%d/%m/%Y")
          start_dt   = row[:start_dt].strftime("%d/%m/%Y")
          end_dt     = row[:end_dt].strftime("%d/%m/%Y")
          nome       = row[:nome]
          Base64.strict_encode64(nome + "-" + dt_upd + "-" + start_dt + "-" + end_dt)
        end
      end

      #
      # Controlla nel db remit se ho già una remit uguale
      #
      # @param unique_id [String]
      #
      # Success => @return [Success(0)]       | codice 0 quindi posso proseguire non mi interessa il valore di ritorno
      # Failure => @return [Failure(String)]  | ho già una remit uguale interoppe esecuzione e restituisce un messsaggio
      #
      def check_exist_in_db(unique_id)
        exist = coll_remit.find({ unique_id: unique_id }).limit(1).first
        exist ? Failure("Ho una remit uguale a db non verra' archiviata") : Success(0)
      end

      #
      # Mi crea il mio doc aggiungendo alla riga che ha letto dall'excel
      # id_transmission e unique_id e rimove dall'hash la key decision
      #
      # @todo: vedere se è meglio creare una stinga base64 fare una query su piu campi per le performance
      #
      # @param row       row [Hash]        | hash che rappresenta il documento che deve essere iserito a db
      # @param id        [BSON::ObjectId]  | id della linea che corrispondente nel Db transmission
      # @param unique_id [String]          | id univoco che mi identifica la remit
      #
      # Success    => @return [Success(Hash)]       | documento da inserire nel DB remit
      # Failure(e) => @return [Failure(Exception)]  | uscita inaspettata ritorna l'eccezione
      #
      def make_doc(row, id, unique_id)
        try! do
          rm_decison = ->(hash) { hash.delete_if { |k,v| k == :decision } }
          row.
            ᐅ(~:dup).
            ᐅ(~:merge, {id_transmission: id, unique_id: unique_id}).
            ᐅ(rm_decison)
        end
      end

      #
      # Accoda il documento da inserire per inserirlo succesivamente in modalità bulk
      #
      # @param doc [Hash] | hash che rappresenta il documento che deve essere iserito a db
      #
      # Success => @return [Success(0)] | codice 0 quindi posso proseguire non mi interessa il valore di ritorno
      #
      def insert_in_bulk_op(doc)
        @bulk_op << {insert_one: doc}
        # result = coll_remit.insert_one(doc)
        # fare il check se riuscito a salvare la linea usando result
        # result.n
        logger.info("Archiviato la linea a db".green)
        Success(0)
      end

      sequence_scan_for_archive(remit_terna)
    end #END scan_for_archive

    #
    # Inserisce nel mio database le remit
    #
    def write_bulk_op
      begin
        result = coll_remit.bulk_write(@bulk_op, :write => {:w => 1})
        count = result.inserted_count || 0
        logger.info("Inserito #{count} remit a DB ")
        Success(0)
      rescue => e
        Failure(e)
      end
    end

    #
    # Delle remit che non ha inserito a DB prende solo quelle che ha trovato
    # una corrispondenza di nome con il DB transmission
    #
    def get_match
      @no_archiviate.match.empty? ? Success(nil) : Success(@no_archiviate.match)
    end

    #
    # Crea il file excel per le remit non inserite a DB
    #
    def make_file_xlsx(file, **data)
      return Success(nil) if data.values[0].nil?

      #
      # @todo: per velocizzare usare questa gemma fast_excel
      #
      def make_file(data, type)
        return Success(nil) if data.nil?
        try! do
          workbook  = RubyXL::Parser.parse("./template/template.xlsx")
          worksheet = workbook[0]

          data.each_with_index do |row, row_index|
            excel_row = doc_to_excel_row(row)
            excel_row << (type == "match" ? "SI" : "NO")
            excel_row.each_with_index do |column, column_index|
              worksheet.add_cell(5+row_index, column_index, column)
            end
          end
          Success(workbook)
        end
      end

      def make_path(file, type)
        return Success(nil) if file.nil?
        try! do
          folder = type == "match" ? Transmission::Config.path.match : Transmission::Config.path.nomatch
          file.
            ᐅ(~:split, "/").
            ᐅ(~:last).
            ᐅ(~:sub, ".xlsx", "_#{type}.xlsx").
            ᐅ(~:prepend, folder)
        end
      end

      def write_xlsx(workbook, path)
        return Success(nil) if workbook.nil?
        try! do
          workbook.write(path)
        end
      end

      type = data.keys[0].to_s
      data = data.values[0]
      in_sequence do
        get(:workbook_match)     { make_file(data, type)               }
        get(:path)               { make_path(file, type)               }
        and_then                 { write_xlsx(workbook_match, path)    }
        and_yield                { Success(path)                       }
      end
    end

    #
    # Delle remit che non ha inserito a DB prende solo quelle che non
    # hanno neesuna corrispondenza di nome con il DB transmission
    #
    def get_nomatch
      @no_archiviate.no_match.empty? ? Success(nil) : Success(@no_archiviate.no_match)
    end

    #
    # Crea il l'html da inserire nell'email e invia email
    #
    def make_report(match_path, match, nomatch_path, nomatch)
      if match_path.nil? && nomatch_path.nil?
        return Success(0)
      end

      make_html  = MakeHtml.new(match, nomatch)
      send_email = SendEmail.new(match_path, nomatch_path)

      make_html.call() >> ->(html) { send_email.call(html) }
    end

    #
    # Sposta il file della remit in archivio
    #
    def sposta_file(file)
      try! do
        folder    = Transmission::Config.path.archivio
        file_name = file.split("/").last
        dest      = folder + file_name
        FileUtils.mv file, dest
      end
    end

    #
    # Esegue sincronizzazione con la cartella di rete
    #
    def sincronizzazione
      sync(type: 'push')
    end

    results = in_sequence_archivia

    Success(results) >> method(:formatta) >> method(:stampa)
  end #END archvia

  #
  # Lista dei file presenti nella cartella download
  #
  def lista_file
    Dir.glob(Transmission::Config.path.download + "/*.xlsx")
  end

  def doc_to_excel_row(row)
    nome            = row[:nome]
    type_of_line    = "LIN"
    volt            = row[:volt]
    # start_dt        = row[:start_dt].to_date
    start_dt        = row[:start_dt].strftime("%d/%m/%Y")
    start_hour      = row[:start_dt].strftime("%H:%M:%S")
    stop_dt         = row[:end_dt].strftime("%d/%m/%Y")
    stop_hour       = row[:end_dt].strftime("%H:%M:%S")
    daily_rest      = ""
    reason          = row[:reason]
    possibile_match = row[:possibile_match]
    return [nome, type_of_line, volt, start_dt, start_hour, stop_dt, stop_hour, daily_rest, reason, possibile_match]
  end

  def formatta(results)
    msg = []
    results.each do |r|
      if r.success?
        msg << r.value.green
      else
        if r.value.class.ancestors.include? Exception
          bkt = r.value.backtrace.select { |v| v =~ /#{APP_NAME}/ }[0]
          msg << (r.value.message + "\n" + bkt).red
        else
          msg << r.value.red
        end
      end
      msg
    end
    Success(msg)
  end

  def stampa(messaggi)
    Success(messaggi.each{|m| render(msg: m)})
  end

  #
  # Prende in input una data e un time e mi restituisce un DateTime
  #
  # @param  date [Date]
  # @param  time [Time]
  #
  # @return[DateTime]
  #
  def to_datetime(date, time)
    DateTime.new(date.year, date.month, date.day, time.hour, time.min, time.sec, time.zone)
  rescue
    DateTime.new(date.year, date.month, date.day)
  end

  #
  # Mi restituisce tutti i documenti presnti nel db transmission
  # dei documenti mi restitusce solo id e nome
  #
  # @example ogni record è in questa forma
  #   {"_id"=>BSON::ObjectId('23668...'), "properties"=>{"nome"=>"003 - fiume santo - ittiri"}}
  #
  # @return [Array<Hash>] ogni riga è un record del mio db
  #
  def all_line
    db.ᐅ(~:all_document_from, collection: "transmission")
  end

  #
  # Crea un nuovo oggetto TransmissionModel e mi stabilisce la connesione con il db
  #
  #
  def db
    TransmissionModel.new
  end

  #
  # Seleziono la collezzione transmission
  #
  def transmission_380
    url     = "https://api.mapbox.com/datasets/v1/browserino/cjcb6ahdv0daq2xnwfxp96z9t/features?access_token=sk.eyJ1IjoiYnJvd3NlcmlubyIsImEiOiJjamEzdjBxOGM5Nm85MzNxdG9mOTdnaDQ0In0.tMMxfE2W6-WCYIRzBmCVKg"
    geojson = open(url, {ssl_verify_mode: 0}).read
    Oj.load(geojson, :symbol_keys => true, :mode => :compat)[:features]
  end

  #
  # Seleziono la collezzione remit
  #
  def coll_remit
    db.collection(collection: "remit")
  end

  #
  # Mi stampa un log
  #
  def log(level, message)
    logger.send(level, message)
  end

  memoize :db
  # memoize :coll_transmission
  memoize :coll_remit
  memoize :all_line
  memoize :lista_file

end

