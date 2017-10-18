# frozen_string_literal: true

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

class ArchiviaController < Transmission::BaseController
  extend Memoist

  def start
    lista_file.ᐅ method(:exit_if_not_files)
    exit
    files = lista_file

     exit_if_not_file

    (exit! 2) unless there_is_file?
    
    result = files.map do |file|
      @no_archiviate = NoArchivate.new(file)
      in_sequence do
        get(:remit)              { leggi_remit(file)                                          }
        and_then                 { archivia_remit(remit)                                      }
        get(:match)              { get_match_no_archiviate                                    }
        get(:match_path)         { make_file_xlsx(file, match: match)                         }
        get(:nomatch)            { get_nomatch_no_archiviate                                  }
        get(:nomatch_path)       { make_file_xlsx(file, nomatch: nomatch)                     }
        and_then                 { make_report(match_path, match, nomatch_path, nomatch)      }
        and_then                 { sposta_file(file)                                          }
        and_yield                { Success("Archiviata #{file.split("/").last} con successo") }
      end
    end
    Success(result) >> method(:formatta) >> method(:stampa)
  end

  private

  #
  # Lista dei file presenti nella cartella download
  #
  def lista_file
    Dir.glob(Transmission::Config.path.download + "/*.xlsx")
  end


  #
  # Controllo se ho almeno un file da leggere
  # se non ci sono file esce
  #
  def exit_if_not_files(files)
    if files.empty?
      Yell['scheduler'].warn("Nessun file da archiviare")
      (exit! 2) 
    end
  end

  ######################################
  #      METODI UTILIZZO VARIO         #
  ######################################

  def make_file_xlsx(file, **data)
    return Success(nil) if data.values[0].nil?
    type = data.keys[0].to_s
    data = data.values[0]
    in_sequence do
      get(:workbook_match)     { make_file(data, type)               }
      get(:path)               { make_path(file, type)               }
      and_then                 { write_xlsx(workbook_match, path)    }
      and_yield                { Success(path)                       }
    end
  end

  def make_report(match_path, match, nomatch_path, nomatch)
    if match_path.nil? && nomatch_path.nil?
      return Success(nil)
    end

    try! do
      match   = sanitize(match)   if match
      nomatch = sanitize(nomatch) if nomatch
      html  = ERB.new(File.read("./template/report.html.erb"),nil, '-').result(binding)
      
      Transmission::BaseMail.send(html, match_path, nomatch_path)
    end
  end

  #
  # Sposta il file della remit
  # se qualche remit non è stata letta lo sposta in Partial
  # o se no lo sposta in archivio
  #
  def sposta_file(file)
    try! do
      folder    = Transmission::Config.path.archivio
      file_name = file.split("/").last
      dest      = folder + file_name
      FileUtils.mv file, dest
    end
  end

  def sanitize(data)
    to = ->(v) {
        case v
          when DateTime then v.strftime("%d/%m/%Y %R")
          when String   then v.gsub(/linea/i, "")
          else v 
        end
      }
    key = ->(k,_) { k == :decision }

    sanitize_match = data.map do |row|
      row.
        ᐅ(~:transform_values!, &to).
        ᐅ(~:delete_if, &key)
    end
  end

  def get_match_no_archiviate
    @no_archiviate.match.empty? ? Success(nil) : Success(@no_archiviate.match)
  end

  def get_nomatch_no_archiviate
    @no_archiviate.no_match.empty? ? Success(nil) : Success(@no_archiviate.no_match)
  end

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

  def formatta(result)
    msg = []
    result.each do |r|
      if r.success?
        msg << r.value.green
        # render(msg: msg) if $INTERFACE != "scheduler"
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
    # Success(messaggi.each{|m| render(msg: m) if $INTERFACE != "scheduler"})
  end

  ######################################
  #  METODI PER LETTURA FILE REMIT     #
  ######################################

  #
  # Legge il file della remit
  # 
  # @param file  [String] "./excel_file//remit_YYYY_M_D.xlsx"
  # 
  # @note in_sequence:
  #         - open_xlsx
  #         - get_sheet
  #         - get_dt_upd
  #         - get_values
  #
  # @return [Success(Array<Hash>)] ogni riga e un elemento del mio array
  #
  def leggi_remit(file)
    in_sequence do
      get(:xlsx)      { open_xlsx(file)            }
      get(:sheet)     { get_sheet(xlsx)            }
      get(:dt_upd)    { get_dt_upd(file)           }
      get(:value)     { get_values(sheet, dt_upd)  }
      and_yield       { Success(value)             }
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

  #
  # Prende le righe dal folgio della remit
  #
  # @note - elimina le prime 5 righe
  #       - applica un filtro per prendere solo i valori che mi servono(LIN e 400 kV)
  #
  # @return[Array<Array>]
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
  # Apre il file della remit
  #
  # @return[SimpleXlsxReader::Document]
  #
  def open_xlsx(file)
    try! {SimpleXlsxReader.open(file)}
  end

  #
  # Prende in input una data e un time e mi restituisce un DateTime
  #
  # @param  date [Date]
  # @param  timw [Time]
  #
  # @return[DateTime]
  #
  def to_datetime(date, time)
    DateTime.new(date.year, date.month, date.day, time.hour, time.min, time.sec, time.zone)
  rescue
    DateTime.new(date.year, date.month, date.day)
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

  ######################################
  #    METODI PER ARCHVIAZIONE A DB    #
  ######################################

  #
  # Avvia il processo di archiviazione a db utilizzando in_sequence
  # se una sola delle azzioni non va a buon fine tutte le azzioni
  # successive non vengono eseguite
  # Nel caso in cui avessi un Failure prima della fine della sequenza
  # mi viene segnalato con un logger.warn
  #
  def archivia_remit(remit_terna)
    try! do
      remit_terna.each do |row|
        row.freeze
        nome_terna = row[:nome]

        archivia = in_sequence do
          get(:id_trovato)   { transmission_id(nome_terna)                           }
          get(:id)           { id_trovato ? Success(id_trovato) : possibili_id(row)  }
          get(:ui)           { unique_id(row)                                        }
          and_then           { check_exist_in_db(ui)                                 }
          get(:doc)          { make_doc(row, id, ui)                                 }
          and_then           { archivia(doc)                                         }
          and_yield          { Success("Archiviata con successo")                    }
        end

        logger.warn(archivia.to_s) if (archivia.failure?)

        logger.info "\n"+ "#"*80 + "\n"
      end
    end
  end

  #
  # Cerca nella collezione transmission il nome della linea
  # se lo trova mi restituisce l'id altrimenti nil
  #
  def transmission_id(nome_terna)
    logger.info "Cerco per #{nome_terna} l'id della linea nel db transmission"

    doc = coll_transmission.
      ᐅ(~:find, {"properties.nome_terna" => nome_terna}).
      ᐅ(~:limit, 1).
      ᐅ(~:to_a)

    if doc.empty?
      logger.warn "Per #{nome_terna} non ho trovato nessun id".red
      Success(nil)
    else
      id = doc_id(doc)
      logger.info "Trovato per #{nome_terna} => #{id}".green
      Success(id)
    end
  end

  #
  # Cerca nel db transmission le linee che potrebbere matchare con il nome
  #
  def possibili_id(row)
    logger.info "Cerco nel db i possibili id che possono corrispondere al nome"
    nome                 = row[:nome]
    row                  = row.dup
    id_terna, nome_clean = clean_name(nome)

    # logger.debug "id_terna:     #{id_terna}"
    logger.info "nome linea:      #{nome}".rjust(5)

    trovato = fuzzy_search_possible_line(id_terna, nome_clean)

    if trovato.nil?
      logger.info "Non trovo nessuna linea"
      row[:possibile_match] = 'nessuno'
      @no_archiviate.no_match << row
      return Failure("Questa remit non viene archiviata a DB".red)
    end

    if (trovato[1] < 0.16) && (trovato[2] < 0.16)
      logger.info("Trovato: #{trovato[0].dig("properties","nome")}")
      logger.info("Score troppo basso: #{trovato[1].to_s} #{trovato[2].to_s}".red)
      row[:possibile_match] = 'nessuno'
      @no_archiviate.no_match << row
      return Failure("Questa remit non viene archiviata a DB".red)
    end

    possibile_match       = trovato[0].dig("properties","nome")
    row[:possibile_match] = possibile_match
    logger.info("Trovato a db:    " + possibile_match)
    id_transmission = trovato[0]["_id"]

    if row[:decision] == "SI"
      logger.info("Sto leggendo un file adjust")
      logger.info("In decision ho SI")
      salva_nome_terna(id_transmission, nome)
      return Success(id_transmission)
    end

    if row[:decision] == "NO"
      logger.info("Sto leggendo un file adjust")
      logger.info("In decision ho NO")
      @no_archiviate.match << row
      return Failure("Questa remit non viene archiviata a DB".red)
    end

    if $INTERFACE == "scheduler"
      @no_archiviate.match << row
      return Failure("Questa remit non viene archiviata a DB".red)
    end

    if salvo_nome_in_db?
      salva_nome_terna(id_transmission, nome)
      Success(id_transmission)
    else
      @no_archiviate.match << row
      Failure("Utente non vuole salvare il nome della linea a DB")
    end
  end

  #
  # Utilizza la gemma fuzzymatch per cercare tra tutte le linee che ho in anagrafica
  # il nome che piu assomiglia al nome della linea che sto leggendo
  #
  def fuzzy_search_possible_line(id_terna, nome)
    # @todo: ho utilizzato per all_line la memoize vedere se puo dare problemi
    # in caso inserisco una linea e ho la stassa linea nello stesso file
    fuzzy_match = FuzzyMatch.new(all_line, :groupings => [/#{id_terna}/], :must_match_grouping => true)
    fuzzy_match.find_with_score(nome)
  end

  #
  # Inserisce in documento nel db remit
  #
  # @todo: migliorare performance per inserire piu doc in un momento
  #
  def archivia(doc)
    result = coll_remit.insert_one(doc)
    # fare il check se riuscito a salvare la linea usando result
    # result.n
    logger.info("Archiviato la linea a db".green)
    Success(0)
  end

  #
  # Controlla nel db remit se ho già una remit uguale
  #
  def check_exist_in_db(unique_id)
    exist = coll_remit.find({ unique_id: unique_id }).limit(1).first
    exist ? Failure("Ho una remit uguale a db non verra' archiviata") : Success(0)
  end

  #
  # Mi crea il mio doc aggiungendo alla riga che ha letto dall'excel
  # id_transmission e unique_id
  #
  # @todo: vedere se è meglio creare una stinga base64 fare una query su piu campi
  # per le performance
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
  # Concatena dt_upd start_dt end_dt nome, e mi crea un id univoco in base64
  #
  def unique_id(row)
    try! {
      dt_upd     = row[:dt_upd].strftime("%d/%m/%Y")
      start_dt   = row[:start_dt].strftime("%d/%m/%Y")
      end_dt     = row[:end_dt].strftime("%d/%m/%Y")
      nome       = row[:nome]
      Base64.strict_encode64(nome + "-" + dt_upd + "-" + start_dt + "-" + end_dt)
    }
  end

  #
  # Mi chiede se voglio salvare la linea a db
  #
  def salvo_nome_in_db?
    prompt = TTY::Prompt.new
    prompt.yes?('Vuoi salvare il nome della linea?'.green)
  end

  #
  # Chiede all'utente se vuole salvare il nome di terna nel db transmission
  #
  def salva_nome_terna(id_transmission, nome)
    logger.debug "Salvo il nome_terna a db"

    doc_id_transmission   = coll_transmission.find({_id: id_transmission}).limit(1)
    array_nome_terna_size = doc_id_transmission.first.dig("properties","nome_terna").size

    logger.info "Attenzione questa linee ha gia #{array_nome_terna_size} nomi" if array_nome_terna_size > 0

    result = doc_id_transmission.update_one({'$addToSet' => {"properties.nome_terna": nome}})

    if result.modified_count == 1
      logger.info "nome_terna #{nome} salvato nel db"
    end
  end

  #
  # Mi estrae l'id dal documento
  #
  def doc_id(doc)
    doc[0]["_id"]
  end

  #
  # Mi restituisce tutti i documenti presneti nel db transmission
  #
  def all_line
    db.ᐅ(~:all_document_from, collection: "transmission")
  end

  #
  # Prende il nome della linea che ha letto dall'excel e fa un sanitizze
  # e mi restitusce l'id e il nome della linea
  #
  def clean_name(nome)
    nome = nome.dup
    nome.downcase!
    nome.sub!("linea 400 kv ", "")
    nome.sub!("linea ", "")
    id = nome.match(/\d{3}/)
    id = id.nil? ? "" : id[0]
    # nome.sub!(id, "")
    nome.sub!(/l\s/, "")
    nome.strip!
    return id.to_s, nome
  end

  #
  # Crea un nuovo oggetto TransmissionModel e mi stabilisce la connesione con il db
  #
  def db
    TransmissionModel.new
  end

  #
  # Seleziono la collezzione transmission
  #
  def coll_transmission
    db.collection(collection: "transmission")
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
  memoize :coll_transmission
  memoize :coll_remit
  memoize :all_line
  #
end
