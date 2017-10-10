# frozen_string_literal: true

# STDOUT.sync = true


class ArchiviaController < Transmission::BaseController
  extend Memoist

  def start
    # @todo: per ora prendo l'ultimo ma devo fare che li scansiona
    # tutti e legge quelli non letti
    @files  = lista_file

    exit! unless file_exist?

    result = @files.map do |file|
      @no_archiviate = []
      result = in_sequence do
        get(:remit)                { leggi_remit(file)             }
        and_then                   { archivia_remit(remit)         }
        get(:match)                { get_match                     }
        and_then                   { make_file_match(match)        }
        # get(:nomatch)              { get_no_match                  }
        # and_then                   { make_file_no_match(nomatch)   }
        # and_then                   { make_report                   }
        # and_then                   { sposta_file(file)             }
        and_yield                  { Success("Archiviata #{file.split("/").last} con successo") }
      end
    end
    Success(result) >> method(:formatta) >> method(:stampa)
  end

  private

  ######################################
  #      METODI UTILIZZO VARIO         #
  ######################################

  #
  # Sposta il file della remit
  # se qualche remit non è stata letta lo sposta in Partial
  # o se no lo sposta in archivio
  #
  def sposta_file(file)
    try! do
      folder    = @no_archiviate.empty? ? Transmission::Config.path.archivio : Transmission::Config.path.partial
      file_name = file.split("/").last
      dest      = folder + file_name
      FileUtils.mv file, dest
    end
  end

  def make_report
    try! do
      sanitize = @no_archiviate.map do |row|
        row.transform_values! do |v|
          if v.is_a? DateTime
            v.strftime("%d/%m/%Y %R")
          elsif v.is_a? String
            v.gsub(/linea/i, "")
          else
            v
          end
        end
      end
      group   = sanitize.group_by do |x| x[:possibile_match] == "nessuno" ? :nomatch : :match end
      match   = group[:match]
      nomatch = group[:nomatch]

      html = ERB.new(File.read("./template/report.html.erb"),nil, '-').result(binding)

      Transmission::BaseMail.send(html)
    end
  end

  def get_match
    if @no_archiviate.empty?
      Success(nil)
    else
      group  = @no_archiviate.group_by do |x| x[:possibile_match] == "nessuno" ? :nomatch : :match end
      Success(group[:match])
    end
  end

  def get_no_match
    if @no_archiviate.empty?
      Success(nil)
    else
      group  = @no_archiviate.group_by do |x| x[:possibile_match] == "nessuno" ? :nomatch : :match end
      Success(group[:nomatch])
    end
  end

  #
  # @todo: per velocizzare usare questa gemma fast_excel
  #
  def make_file_match(match)
    workbook  = RubyXL::Parser.parse("./template/template.xlsx")
    worksheet = workbook[0]
    match.each_with_index do |row,row_index|
      excel_row = doc_to_excel_row(row)
      # row.delete(:dt_upd)
      excel_row.each_with_index do |column, column_index|
        worksheet.add_cell(5+row_index, column_index, column)
      end
    end
    workbook.write("match.xlsx")
    Success(0)
  end

  def doc_to_excel_row(row)
    nome            = row[:nome]
    type_of_line    = "LIN"
    volt            = row[:volt]
    start_dt        = row[:start_dt].strftime("%d/%m/%Y")
    start_hour      = row[:start_dt].strftime("%H:%M:%S")
    stop_dt         = row[:end_dt].strftime("%d/%m/%Y")
    stop_hour       = row[:end_dt].strftime("%H:%M:%S")
    daily_rest      = ""
    reason          = row[:reason]
    possibile_match = row[:possibile_match]
    decison         = "SI" 
    return [nome, type_of_line, volt, start_dt, start_hour, stop_dt, stop_hour, daily_rest, reason, possibile_match, decison]
  end

  def make_file_no_match(nomatch)
    workbook  = RubyXL::Parser.parse("./template/template.xlsx")
    worksheet = workbook[0]
    nomatch.each_with_index do |row,row_index|
      row = row.dup
      row.delete(:dt_upd)
      row[:decison] = "no"
      row.to_a.each_with_index do |column,column_index|
        cell = worksheet[5+row_index][column_index]
        if cell.nil?
          worksheet.add_cell(5+row_index, column_index, column[1])
        else
          cell.change_contents(column[1])
        end
      end
    end
    workbook.write("nomatch.xlsx")
    Success(0)
  end

  def formatta(result)
    msg = []
    format_result = result.collect do |r|
      if r.success?
        msg << r.value.green
        # render(msg: msg) if $INTERFACE != "scheduler"
      else
        unless r.value.class.ancestors.include? Exception
          msg << r.value.red
        else
          msg << r.value.message.red
          # @todo: migliore l'output delle eccezioni con pretty_backtrace
          # bkt = ""
          # binding.pry
          # r.value.backtrace.select { |v| v =~ /download_controller.rb/ }.each do |x| bkt << x.red end
          # msg[r.value.message] = bkt
        end
      end
      msg
    end
    Success(msg)
  end

  def stampa(messaggi)
    Success(messaggi.each{|m| render(msg: m) if $INTERFACE != "scheduler"})
  end

  ######################################
  #  METODI PER LETTURA FILE REMIT     #
  ######################################

  def leggi_remit(file)
    in_sequence do
      get(:xlsx)      { open_xlsx(file)            }
      get(:sheet)     { get_sheet(xlsx)            }
      get(:dt_upd)    { get_dt_upd(file)           }
      get(:value)     { get_values(sheet, dt_upd)  }
      and_yield       { Success(value)             }
    end
  end

  def file_exist?
    if @files.empty?
      print "non trovo nessun file remit\n"
      return false
    end
    true
  end

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
  def get_values(sheet, dt_upd)
    try! do
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
        {nome: nome, volt: volt, dt_upd: dt_upd, start_dt: start_dt, end_dt: end_dt, reason: reason}
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
    try! do file.
      ᐅ(~:sheets).
      ᐅ(~:first).
      ᐅ(~:rows).
      ᐅ(~:drop, 5).
      ᐅ(~:keep_if, &filter)             end
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
      to_datetime =  ->(string) { DateTime.strptime(string,"%Y_%m_%d") }
      file.
        ᐅ(~:split, '/').
        ᐅ(~:last).
        ᐅ(~:gsub, /remit_|.xlsx/i, "").
        ᐅ(to_datetime)
    end
  end

  ######################################
  #    METODI PER ARCHVIAZIONE A DB    #
  ######################################

  def archivia_remit(remit_terna)
    try! do
      remit_terna.each do |row|
        logger.debug "#"*80+"\n"
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

        logger.warn(archivia.to_s) if (archivia.failure?) && ($INTERFACE != "scheduler")
      end
    end
  end

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

    if doc.empty?
      logger.debug "Per #{nome_terna} non ho trovato nessun id"
      Success(nil)
    else
      id = doc_id(doc)
      logger.debug "Trovato per #{nome_terna} => #{id}"
      Success(id)
    end
  end

  #
  # Cerca nel db transmission le linee che potrebbere matchare con il nome
  #
  def possibili_id(row)
    logger.debug "Cerco nel db i possibili id che possono corrispondere al nome"
    nome = row[:nome]
    row  = row.dup
    id_terna, nome_clean = clean_name(nome)
    # logger.debug "id_terna:     #{id_terna}"
    logger.debug "nome linea:      #{nome}".rjust(5)

    f = FuzzyMatch.new(all_line, :groupings => [/#{id_terna}/], :must_match_grouping => true)
    trovato = f.find_with_score(nome_clean)
    if trovato.nil?
      logger.info "Non trovo nessuna linea"
      row[:possibile_match] = 'nessuno'
      @no_archiviate << row
      Failure("Questa remit non viene archiviata a DB")
    elsif (trovato[1] < 0.16) && (trovato[2] < 0.16)
      logger.info "Trovato: #{trovato[0].dig("properties","nome")}"
      logger.info "Score troppo basso: #{trovato[1].to_s} #{trovato[2].to_s}"
      row[:possibile_match] = 'nessuno'
      @no_archiviate << row
      Failure("Questa remit non viene archiviata a DB")
    else
      possibile_match       = trovato[0].dig("properties","nome")
      row[:possibile_match] = possibile_match
      logger.debug "Trovato a db:    " + possibile_match
      if $INTERFACE == "scheduler"
        @no_archiviate << row
        Failure("Questa remit non viene archiviata a DB")
      else
        id_transmission = trovato[0]["_id"]
        if salva_nome_terna(id_transmission, nome)
          Success(id_transmission)
        else
          @no_archiviate << row
          Failure("Utente non vuole salvare il nome della linea a DB")
        end
      end
    end
  end

  #
  # Inserisce in documento nel db remit
  #
  # @todo: migliorare perfomnce per inserire piu doc in un momento
  #
  def archivia(doc)
    # result = coll_remit.insert_one(doc)
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
