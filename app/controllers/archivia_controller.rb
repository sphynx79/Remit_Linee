# frozen_string_literal: true
#
class ArchiviaController < Transmission::BaseController
  extend Memoist

  attr_reader :file

  def start
    # @todo: per ora prendo l'ultimo ma devo fare la logica che li scansiona
    # tutti e legge quelli non letti
    @file = lista_file.last
    values = read_file
    ap values
    # render
  end

  #
  # Lista dei file presenti nella cartella download
  #
  # @return [Array]
  #
  def lista_file
    Dir.glob(env[:config].path["download"]+"/*.xlsx")
  end

  def read_file
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

  def file_xlsx
    SimpleXlsxReader.open(@file)
  end

  def sheet
    filter = ->(row) {row[1] == "LIN" &&  row[2] == "400 kV"}
    sheet  = file_xlsx.
      ᐅ(~:sheets).
      ᐅ(~:first).
      ᐅ(~:rows).
      ᐅ(~:drop, 5).
      ᐅ(~:keep_if, &filter)
  end

  def to_datetime(date, time)
    DateTime.new(date.year, date.month, date.day, time.hour, time.min, time.sec, time.zone)
  rescue
    DateTime.new(date.year, date.month, date.day)
  end

  def dt_upd
    to_datetime =  ->(string) { DateTime.strptime(string,"%Y_%m_%d") }
    @file.
      ᐅ(~:split, '/').
      ᐅ(~:last).
      ᐅ(~:gsub, /remit_|.xlsx/i, "").
      ᐅ(to_datetime)
  end

  memoize :dt_upd

end
