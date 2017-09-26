# frozen_string_literal: true

# @todo: eliminare zlog e usare yell
require 'zlog'
Log = Logging.logger["main"]
Zlog::init_stdout loglevel: :debug

class ArchiviaController < Transmission::BaseController
  extend Memoist
  include Deterministic::Prelude

  attr_reader :file
  attr_reader :values

  def start
    # @todo: per ora prendo l'ultimo ma devo fare la logica che li scansiona
    # tutti e legge quelli non letti
    @file        = lista_file.last
    controlla_nome_terna
    # ap values
    # render
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

  def controlla_nome_terna
    # ap db.all_document_from(collection: "transmission")
    # ap db.ᐅ(~:all_document_from, collection: "transmission")

    remit_terna.each do |row|
      row.freeze
      nome = row[:nome]
      docs = []

      result = in_sequence do
        get(:id)   { trova_transmission_id(nome_terna: nome) }
        get(:doc)  { merge_row_and_id(row, id)               }
        get(:_)    { archivia_linea(doc)                     }
        # observe     { log('info', msg) }
        # and_then    { change_env_path  }
        # get(:msg)   { create_tags      }
        # observe     { log('info', msg) }
        # get(:msg)   { create_gems_tags }
        # observe     { log('info', msg) }
        and_yield   { Success("Fine controllo nome terna ") }
      end

      Log.error(result.to_s) if result.failure?

      # if exist_in_db(nome_terna: nome)
      #   Log.debug "nome_terna: #{nome} gia presente nel db"
      # else
      #   Log.debug "nome_terna: #{nome} non presente a db"
      #   id_transmission = search_id_transmission(nome)
      #   # salva_nome_terna_in_db(id_transmission, nome) if id_transmission
      # end

    end
  end


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

 
  def trova_transmission_id(nome_terna:)
    Log.section "Cerco l'id della linea nel db transmission"

    docs = coll_transmission.
      ᐅ(~:find, {"properties.nome_terna" => nome_terna}).
      ᐅ(~:limit, 1).
      ᐅ(~:to_a)

    if docs.empty?
      Log.warn "Per #{nome_terna} non ho trovato nessun id"
      cerca_possibili_id(nome_terna)
    else
      id = transmission_id(docs)
      Log.ok "Trovato per #{nome_terna} => #{id}"
      Success(id)
    end
  end

  def archivia_linea(doc)
    Log.debug "Archivio la linea a db"
    Success(0)
  end

  def merge_row_and_id(row, id)
    try! {row.dup.merge({id_transmission: id})}
  end

  def cerca_possibili_id(nome)
    Log.warn "Cerco nel db i possibili id che possono corrispondere al nome"
    # id_terna, nome_clean = clean_name(nome)
    # Log.debug "id_terna: #{id_terna}"
    # Log.debug "nome: #{nome}".rjust(5)
    #
    # f = FuzzyMatch.new(all_line, :groupings => [/#{id_terna}/], :must_match_grouping => true)
    # trovato = f.find_with_score(nome_clean)
    # if trovato.nil?
    #   Log.error "Non trovo nessuna linea"
    #   nil
    # elsif (trovato[1] < 0.16) && (trovato[2] < 0.16)
    #   Log.error "Trovato: #{trovato[0].dig("properties","nome")}"
    #   Log.error "Score troppo basso: #{trovato[1].to_s} #{trovato[2].to_s}"
    #   nil
    # else
    #   Log.debug "Trovato: " + trovato[0].dig("properties","nome")
    #   trovato[0]["_id"]
    # end
    Success(0)

  end

  def transmission_id(docs)
    docs[0]["_id"]
  end

  def all_line
    db.ᐅ(~:all_document_from, collection: "transmission")
  end

  def db
    TransmissionModel.new
  end

  def coll_transmission
    db.collection(collection: "transmission")
  end

  def log(level, message)
    Log.send(level, message)
  end

  memoize :dt_upd
  memoize :db
  memoize :remit_terna
  memoize :coll_transmission
  memoize :all_line

end
