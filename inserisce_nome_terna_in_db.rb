=begin
  Questo script mi serve per leggere un file di remit scaricato da terna
  sito: http://www.terna.it/it-it/sistemaelettrico/transparencyreport/transmissionandinterconnection/plannedoutages.aspx
  Per lanciarlo:
  ruby inserisce_nome_terna_in_db.rb nome_file_da_caricare.xlsx
  Lo script legge il file, filtra le righe 
    type of asset = LIN
    kV            = 400 kV
  Ora per ogni riga controlla se il nome della linea c'è già a DB non fa nulla
  Se il nome della linea non è presente attravero la gemma fuzzy_match
  mi trova le possibili linee presenti a DB che possono fare rifereminto a questo nome
  e se accetto la inserisce a DB nel campo nome_terna che è un array.
  Ho usato un array perche così posso gestire il fatto che se terna da nomi differenti alla linea
  nell'array ho tutti i nomi che terna ha usato per quella linea
  comunque lo script quando deve salvare il nome:terna controlla se nell'array c'è già un nome
  e mi avvisa che c'è gia un nome presente e la salva
  Interessante il fatto dell'uso dei log, mettendo in loglevel debug vedo tutti gli step che fa
=end

gem 'tty-prompt', '= 0.12'
require 'mongo'
require 'simple_xlsx_reader'
require 'pry'
require 'time'
require 'ap'
require 'fuzzy_match'
require 'amatch'
require 'zlog'
require 'tty-prompt'

Log = Logging.logger["main"]
Zlog::init_stdout loglevel: :debug
Mongo::Logger.logger.level = ::Logger::FATAL
FuzzyMatch.engine = :amatch

class RemitTransmission

  def initialize(file)
    @file = file
    @prompt = TTY::Prompt.new
  end

  def start
    read_file
    check_line
  end

  def read_file
    doc   = SimpleXlsxReader.open(@file)
    sheet = doc.sheets.first.rows.drop(5)

    sheet.keep_if { |row| row[1] == "LIN" &&  row[2] == "400 kV" }

    @value = []
    sheet.each do |row|
      nome     = row[0]
      volt     = row[2]
      sd       = row[3]
      st       = row[4]
      ed       = row[5]
      et       = row[6]
      reason   = row[8]
      start_dt = to_datetime(sd, st)
      end_dt   = to_datetime(ed, et)
      @value << {nome: nome, volt: 380, start_dt: start_dt, end_dt: end_dt, reason: reason}
    end
  end

  def check_line
    @client            = connect_db
    @coll_transmission = @client[:transmission]
    @all_line = get_all_line

    @value.each do |v|
      nome = v[:nome]
      if not_exist_in_db(nome_terna: nome)
        Log.debug "nome_terna: #{nome} non presente a db"
        id_transmission = search_id_transmission(nome)
        salva_nome_terna_in_db(id_transmission, nome) if id_transmission
      else
        Log.debug "nome_terna: #{nome} gia presente nel db"
      end
    end

  end

  def get_all_line
    @coll_transmission.find({}).projection('_id' => 1, 'properties.nome' => 1).to_a
  end

  def search_id_transmission(nome)
    Log.section "Cerco l'id della linea che corrisponde al nome di terna"


    id_terna, nome_clean = clean_name(nome)
    Log.debug "id_terna: #{id_terna}"
    Log.debug "nome: #{nome}".rjust(5)
      
    f = FuzzyMatch.new(@all_line, :groupings => [/#{id_terna}/], :must_match_grouping => true)
      trovato = f.find_with_score(nome_clean)
      if trovato.nil?
        Log.error "Non trovo nessuna linea"
        nil
      elsif (trovato[1] < 0.16) && (trovato[2] < 0.16)
        Log.error "Trovato: #{trovato[0].dig("properties","nome")}"
        Log.error "Score troppo basso: #{trovato[1].to_s} #{trovato[2].to_s}"
        nil
      else
        Log.debug "Trovato: " + trovato[0].dig("properties","nome")
        trovato[0]["_id"]
      end
  end

  def salva_nome_terna_in_db(id_transmission, nome)
    
    response = @prompt.ask('Vuoi salvare il nome della linea?', default: 'Yes')
    return if response != "Yes"
    Log.section "Salvo il nome_terna a db"
    doc  = @coll_transmission.find({_id: id_transmission}).limit(1)
    array_nome_terna_size = doc.first.dig("properties","nome_terna").size
    Log.warn "Attenzione questa linee ha gia #{array_nome_terna_size} nomi" if array_nome_terna_size > 0
      
    result = doc.update_one({'$addToSet' => {"properties.nome_terna": nome}})
    if result.modified_count == 1
      Log.debug "nome_terna #{nome} salvato nel db"
    end
  end

  def not_exist_in_db(nome_terna:)
    Log.section "Controllo se il nome esiste gia a db"
    @coll_transmission.find({"properties.nome_terna" => nome_terna}).limit(1).to_a.empty?

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

  def connect_db
    begin
      client = Mongo::Client.new(["127.0.0.1:27017"],
                                 database: 'transmission',
                                 server_selection_timeout: 5,
                                 :write => {:w => 1, :j => false}) #setto la modalità unacknowledged
      client.database_names
      client
    rescue Mongo::Error::NoServerAvailable => e
      Error.report_error('Cannot connect to the server')
    end
  end

  def to_datetime(date, time)
    DateTime.new(date.year, date.month, date.day, time.hour, time.min, time.sec, time.zone)
  rescue
    DateTime.new(date.year, date.month, date.day)
  end

end


ARGV[0].nil? ? (puts "devi dare come input un file"; exit) : file = ARGV[0]

p "il file #{file} non esiste" unless File.exist?(file)

remit = RemitTransmission.new(file)

remit.start
