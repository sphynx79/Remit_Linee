# module Transmission
#
#   class BaseMail
#     def self.send(message)
#       # p "Prepara invio email"
#       from    = 'michele.boscolo@eni.com'
#       to      = 'michele.boscolo@eni.com'
#       subject = 'Linee remit non associate'
#       msg = <<~MESSAGE_END
#         From: #{from}
#         To: #{to}
#         Subject: #{subject}
#         Mime-Version: 1.0
#         Content-Type: text/html; charset=UTF-8
#         Content-Disposition: inline
#         #{message}
#       MESSAGE_END
#
#       begin
#         Net::SMTP.start('relay.eni.pri', 25) do |smtp|
#           smtp.send_message msg, from, to
#         end
#         # p "Email Inviata"
#       rescue Exception => e
#         print "Exception occured: " + e
#       end
#     end
#   end
#
# end

module Transmission

  class BaseMail
    def self.send(message, match_path, nomatch_path)

      p "Prepara invio email"

      from    = 'michele.boscolo@eni.com'
      to      = 'michele.boscolo@eni.com'
      oggi    = (DateTime.now).strftime("%d-%m-%Y")
      subject = "Linee remit non associate #{oggi}"

      marker = "AUNIQUEMARKER"
        head =<<~EOF
        From: #{from}
        To: #{to}
        Subject: #{subject}
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary=#{marker}
        --#{marker}
      EOF


      if match_path != nil
        file_match            = File.open(match_path, 'rb')
        file_content_match    = file_match.read()
        encoded_content_match = [file_content_match].pack("m*")
        file_name             = match_path.
                                  ᐅ(~:split,"/").
                                  ᐅ(~:last).
                                  ᐅ(~:sub, /match/,'adjust')

        match_attach =<<~EOF
          Content-Type: application/vnd.ms-excel; name=\"#{file_name}\"
          Content-Transfer-Encoding: base64
          Content-Disposition: attachment; filename="#{file_name}"
          Content-Description: "#{file_name}"

          #{encoded_content_match}
          --#{marker}
        EOF
      end

      if nomatch_path != nil
        file_nomatch            = File.open(nomatch_path, 'rb')
        file_content_nomatch    = file_nomatch.read()
        encoded_content_nomatch = [file_content_nomatch].pack("m*")
        file_name               = nomatch_path.
                                    ᐅ(~:split,"/").
                                    ᐅ(~:last)
        nomatch_attach =<<~EOF
          Content-Type: application/vnd.ms-excel; name=\"#{file_name}\"
          Content-Transfer-Encoding: base64
          Content-Disposition: attachment; filename="#{file_name}"
          Content-Description: "#{file_name}"

          #{encoded_content_nomatch}
          --#{marker}
        EOF
      end



      # Define the message action
      body =<<~HTML
        Content-Type: text/html; charset=UTF-8

        #{message}
        --#{marker}--
      HTML

       match_attach   = match_path.nil? ? "" : match_attach
       nomatch_attach = nomatch_path.nil? ? "" : nomatch_attach

      msg = head + match_attach + nomatch_attach  + body

      begin
        Net::SMTP.start('relay.eni.pri', 25) do |smtp|
          smtp.send_message msg, from, to
        end
        p "Email Inviata"
      rescue Exception => e
        print  e
      end
    end
  end

end

