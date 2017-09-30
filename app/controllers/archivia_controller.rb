# frozen_string_literal: true

class ArchiviaController < Transmission::BaseController
  extend Memoist
  include Deterministic::Prelude
  include Deterministic::Prelude::Option

  attr_reader :file
  attr_reader :values

  def start
    # @todo: per ora prendo l'ultimo ma devo fare che li scansiona
    # tutti e legge quelli non letti
    @file         = lista_file.last
    @no_archivate = []
    # Transmission::BaseMail.send("prova")

    remit_terna.each do |row|
      row.freeze
      nome_terna = row[:nome]

      result = in_sequence do
        get(:id_trovato)   { transmission_id(nome_terna)                           }
        get(:id)           { id_trovato ? Success(id_trovato) : possibili_id(row)  }
        get(:ui)           { unique_id(row)                                        }
        and_then           { check_exist_in_db(ui)                                 }
        get(:doc)          { make_doc(row, id, ui)                                 }
        and_then           { archivia(doc)                                         }
        and_yield          { Success("Archiviata con successo")                    }
      end

      logger.error(result.to_s) if result.failure?
    end

    message = "\n"
    @no_archivate.each do |k|
      message += "Nome:            #{k[:nome]}\n"
      message += "dt_upd:          #{k[:dt_upd]}\n"
      message += "start_dt:        #{k[:start_dt]}\n"
      message += "end_dt:          #{k[:end_dt]}\n"
      message += "reason:          #{k[:reason]}\n"
      message += "possibile_match: #{k[:possibile_match]}" + "\n"
      message += "\n##############################################################\n"
      message += "\n"
    end

    Transmission::BaseMail.send(message)
  end

  private

  ######################################
  #  METODI PER LETTURA FILE REMIT     #
  ######################################

  #
  # Lista dei file presenti nella cartella download
  #
  def lista_file
    Dir.glob(Transmission::Config.path.download + "/*.xlsx")
  end

  #
  # Legge il file della remit
  #
  # @return [Array<Hash>] ogni riga e un elemento del mio array
  #
  def remit_terna
    sheet.map do |row|
      nome       = row[0]
      volt       = row[2]
      start_date = row[3]
      start_time = row[4]
      end_date   = row[5]
      end_time   = row[6]
      reason     = row[8]
      start_dt   = to_datetime(start_date, start_time)
      end_dt     = to_datetime(end_date, end_time)
      {nome: nome, volt: 380, dt_upd: dt_upd, start_dt: start_dt, end_dt: end_dt, reason: reason}
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
  def sheet
    filter = ->(row) {row[1] == "LIN" &&  row[2] == "400 kV"}
    sheet  = file_xlsx.
      ᐅ(~:sheets).
      ᐅ(~:first).
      ᐅ(~:rows).
      ᐅ(~:drop, 5).
      ᐅ(~:keep_if, &filter)
  end

  #
  # Apre il file della remit
  #
  # @return[SimpleXlsxReader::Document]
  #
  def file_xlsx
    SimpleXlsxReader.open(@file)
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
  def dt_upd
    to_datetime =  ->(string) { DateTime.strptime(string,"%Y_%m_%d") }
    @file.
      ᐅ(~:split, '/').
      ᐅ(~:last).
      ᐅ(~:gsub, /remit_|.xlsx/i, "").
      ᐅ(to_datetime)
  end

  ######################################
  #    METODI PER ARCHVIAZIONE A DB    #
  ######################################

  #
  # Cerca nell collezione transmission il nome della linea
  # se lo trova mi restituisce l'id altrimenti nil
  #
  def transmission_id(nome_terna)
    logger.debug "Cerco l'id della linea nel db transmission"

    doc = coll_transmission.
      ᐅ(~:find, {"properties.nome_terna" => nome_terna}).
      ᐅ(~:limit, 1).
      ᐅ(~:to_a)

    if docs.empty?
      logger.debug "Per #{nome_terna} non ho trovato nessun id"
      Success(nil)
    else
      id = doc_id(doc)
      logger.debug "Trovato per #{nome_terna} => #{id}"
      Success(id)
    end
  end
  
  #
  # Inserisce in documento nel db remit
  #
  # @todo: migliorare perfomnce per inserire piu doc in un momento
  #
  def archivia(doc)
    result = coll_remit.insert_one(doc)
    # fare il check se riuscito a salvare la linea usando result
    # result.n
    logger.debug "Archivio la linea a db"
    Success(0)
  end

  #
  # Controlla nel db remit se ho già una remit uguale
  #
  def check_exist_in_db(unique_id)
    exist = coll_remit.find({ unique_id: unique_id }).limit(1).first
    exist ? Failure("Remit gia presente a db") : Success(0)
  end

  #
  # Mi crea il mio doc aggiungendo alla riga che ha letto dall'excel
  # id_transmission e unique_id
  #
  # @todo: vedere se è meglio creare una stinga base64 fare una query su piu campi
  # per le performance
  #
  def make_doc(row, id, unique_id)
    try! {row.dup.merge({id_transmission: id, unique_id: unique_id})}
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
  # Cerca nel db transmission le linee che potrebbere matchare con il nome
  #
  def possibili_id(row)
    logger.info "Cerco nel db i possibili id che possono corrispondere al nome"
    nome = row[:nome]
    row  = row.dup 
    id_terna, nome_clean = clean_name(nome)
    logger.info "id_terna: #{id_terna}"
    logger.info "nome: #{nome}".rjust(5)

    f = FuzzyMatch.new(all_line, :groupings => [/#{id_terna}/], :must_match_grouping => true)
    trovato = f.find_with_score(nome_clean)
    if trovato.nil?
      logger.warn "Non trovo nessuna linea"
      row[:possibile_match] = 'nessuno'
      @no_archivate << row
      Failure("Questa remit non viene archiviata a DB")
    elsif (trovato[1] < 0.16) && (trovato[2] < 0.16)
      logger.warn "Trovato: #{trovato[0].dig("properties","nome")}"
      logger.warn "Score troppo basso: #{trovato[1].to_s} #{trovato[2].to_s}"
      row[:possibile_match] = 'nessuno'
      @no_archivate << row
      Failure("Questa remit non viene archiviata a DB")
    else
      possibile_match       = trovato[0].dig("properties","nome")
      row[:possibile_match] = possibile_match
      logger.info "Trovato: " + possibile_match
      if $INTERFACE == "scheduler"
        @no_archivate << row
        Failure("Questa remit non viene archiviata a DB")
      else
        id_transmission = trovato[0]["_id"]
        if salva_nome_terna(id_transmission, nome)
          Success(id_transmission)
        else
          @no_archivate << row
          Failure("Utente non vuole salvare il nome della linea a DB")
        end
      end
    end
  end

  #
  # Chiede all'utente se vuole salvare il nome di terna nel db transmission
  #
  def salva_nome_terna(id_transmission, nome)
    prompt = TTY::Prompt.new
    response = prompt.ask('Vuoi salvare il nome della linea?', default: 'Si')
    return false if response != "Si"
    logger.debug "Salvo il nome_terna a db"
    doc  = coll_transmission.find({_id: id_transmission}).limit(1)
    array_nome_terna_size = doc.first.dig("properties","nome_terna").size
    logger.info "Attenzione questa linee ha gia #{array_nome_terna_size} nomi" if array_nome_terna_size > 0

    result = doc.update_one({'$addToSet' => {"properties.nome_terna": nome}})
    if result.modified_count == 1
      logger.debug "nome_terna #{nome} salvato nel db"
    end
  end

  #
  # Mi estrae l'id dal documento 
  #
  def doc_id(doc)
    docs[0]["_id"]
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

  memoize :dt_upd
  memoize :db
  memoize :remit_terna
  memoize :coll_transmission
  memoize :coll_remit
  memoize :all_line

end
