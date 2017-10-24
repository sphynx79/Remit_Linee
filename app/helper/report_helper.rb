module ReportHelper

  class MakeHtml
    attr_reader :match, :nomatch

    def initialize(match, nomatch)
      @match   = match
      @nomatch = nomatch
    end

    def call
      sanitize_match   = sanitize(match)
      sanitize_nomatch = sanitize(nomatch)
      html = ERB.new(File.read("./template/report.html.erb"),nil, '-').result(binding)
      Success(html)
    end

    def sanitize(data)
      return nil if data.nil?
      to = ->(v) {
        case v
        when DateTime then v.strftime("%d/%m/%Y %R")
        when String   then v.gsub(/linea/i, "")
        else v
        end
      }
      key = ->(k,_) { k == :decision }

      data.map do |row|
        row.
          ᐅ(~:transform_values!, &to).
          ᐅ(~:delete_if, &key)
      end
    end

  end

  class SendEmail

    attr_reader :from, :to, :oggi, :subject, :marker, :match_path, :nomatch_path

    def initialize(match_path, nomatch_path)
      @from         = Transmission::Config.mail.from
      @to           = Transmission::Config.mail.to
      @oggi         = (DateTime.now).strftime("%d-%m-%Y")
      @subject      = "Linee remit non associate #{oggi}"
      @marker       = 'AUNIQUEMARKER'
      @match_path   = match_path
      @nomatch_path = nomatch_path
    end

    def call(html)
      head           = make_head
      match_attach   = make_attach(match_path)
      nomatch_attach = make_attach(nomatch_path)
      body           = make_body(html)

      msg = head + match_attach + nomatch_attach  + body

      begin
        Net::SMTP.start('relay.eni.pri', 25) do |smtp|
          smtp.send_message msg, from, to
        end
        logger.debug "Email Inviata"
        Success(0)
      rescue Exception => e
        Failure("Errore nell'invio dell'email")
      end
    end

    def make_head
      <<~EOF
        From: #{from}
        To: #{to}
        Subject: #{subject}
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary=#{marker}
        --#{marker}
      EOF
    end

    def make_body(html)
      body =<<~HTML
        Content-Type: text/html; charset=UTF-8

        #{html}
        --#{marker}--
      HTML
    end

    def make_attach(path)
      return '' if path.nil?
      file            = File.open(path, 'rb')
      file_content    = file.read()
      encoded_content = [file_content].pack("m*")
      file_name       = path.
        ᐅ(~:split,"/").
        ᐅ(~:last).
        ᐅ(~:sub, /_match/,'_adjust')

      attach =<<~EOF
        Content-Type: application/vnd.ms-excel; name=\"#{file_name}\"
        Content-Transfer-Encoding: base64
        Content-Disposition: attachment; filename="#{file_name}"
        Content-Description: "#{file_name}"

        #{encoded_content}
        --#{marker}
      EOF
      return attach
    end

  end

  

end
