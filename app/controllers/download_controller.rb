class DownloadController < Transmission::BaseController
  extend Memoist
  include SyncHelper

  def start
    # @todo: se non ha sincronizzato nessun file non fa nulla
    # https://social.technet.microsoft.com/wiki/contents/articles/1073.robocopy-and-a-few-examples.aspx
    sync(type: 'fetch')

    result = remote_files.map do |row|
      download_file(row)
    end

    downlod_nothing?(result)

    Success(result) >> method(:formatta) >> method(:stampa)
  end

  private

  def remote_files
    begin
      tr = page.css('#dnn_ctr5896_TernaViewDocumentView_grdDocument_ctl00 > tbody > tr')
      if tr.empty?
        raise <<~HEREDOC
        Attenzione controlare la pagina da dove scarico i file deve essere cambiata
        probabilmente e cambiata perche non riesco a trovare nessun file da scaricare
        HEREDOC
      end
      tr
    rescue => e
      Success([Failure(e)]) >> method(:formatta) >> method(:stampa)
      exit!
    end
  end

  def download_file(row)
    def data(row)
      arr_str = λ{|a| "#{a[2]}_#{a[1]}_#{a[0]}"}
      try!{
        row.
        ᐅ(~:css, 'td[2]').
        ᐅ(~:text).
        ᐅ(~:gsub, "/", "_").
        ᐅ(~:split, "_").
        ᐅ(arr_str)
      }
    end

    def file_archivio(data)
      Success("#{archivio_path}/remit_#{data}.xlsx")
    end

    def exist_file(path)
      nome_file = path.split("/").last
      File.exist?(path) ? Failure("File #{nome_file} gia' presente in Archivio") : Success("File #{nome_file} non esiste")
    end

    def url_file(row)
      try!{ row.ᐅ(~:css, 'td[1]/a/@href').ᐅ(~:first).ᐅ(~:value) }
    end

    def remote_file(url)
      try!{open(url, 'User-Agent' => 'ruby')}
    end

    def remote_read(rem_file)
      try!{rem_file.read}
    end

    def local_path(data)
      Success("#{download_path}/remit_#{data}.xlsx")
    end

    def open_local(file)
      try! {open(file, 'wb')}
    end

    def write_local(file, rem_read)
      try! {file.write(rem_read)}
    end

    def close(rem_file)
      try! {rem_file.close}
    end

    row = row.dup.freeze
    in_sequence do
      get(:data)            { data(row) }
      get(:path)            { file_archivio(data) }
      and_then              { exist_file(path) }
      get(:url)             { url_file(row) }
      get(:rem_file)        { remote_file(url) }
      get(:rem_read)        { remote_read(rem_file) }
      get(:path)            { local_path(data) }
      get(:local_file)      { open_local(path) }
      and_then              { write_local(local_file, rem_read) }
      and_then              { close(rem_file) }
      and_yield             { Success("Scaricamento #{path.split("/").last} con successo") }
    end
  end

  def downlod_nothing?(result)
    unless result.detect do |x| x.success? end
    Yell['scheduler'].warn("Nessun file da scaricare")
    end
  end

  def site
    Transmission::Config.url.site
  end

  def page
    Nokogiri::HTML(open(site, {ssl_verify_mode: 0}))
  end

  def download_path
    File.expand_path(Transmission::Config.path.download, APP_ROOT)
  end

  def archivio_path
    File.expand_path(Transmission::Config.path.archivio, APP_ROOT)
  end

  def formatta(result)
    msg = []
    result.each do |r|
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

  memoize :site
  memoize :page
  memoize :download_path
  memoize :archivio_path

end

