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
    def self.send(message)
      # p "Prepara invio email"
      from    = 'michele.boscolo@eni.com'
      to      = 'michele.boscolo@eni.com'
      subject = 'Linee remit non associate'

      marker = "AUNIQUEMARKER"

      # Define the main headers.
      head =<<~EOF
      From: #{from}
      To: #{to}
      Subject: Message with Excel Attachment
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary=#{marker}
      --#{marker}
      EOF


      match   = "match.xlsx"
      file_match  = File.open(match, 'rb')
      file_content_match = file_match.read()
      encoded_content_match = [file_content_match].pack("m*")   # base64
      match_attach =<<~EOF
      Content-Type: application/vnd.ms-excel; name=\"#{match}\"
      Content-Transfer-Encoding: base64
      Content-Disposition: attachment; filename="#{match}"
      Content-Description: "#{match}"

      #{encoded_content_match}
      --#{marker}
      EOF

      nomatch = "nomatch.xlsx"
      file_nomatch  = File.open(nomatch, 'rb')
      file_content_nomatch = file_nomatch.read()
      encoded_content_nomatch = [file_content_nomatch].pack("m*")   # base64
      # Define the attachment section
      nomatch_attach =<<~EOF
      Content-Type: application/vnd.ms-excel; name=\"#{nomatch}\"
      Content-Transfer-Encoding: base64
      Content-Disposition: attachment; filename="#{nomatch}"
      Content-Description: "#{nomatch}"

      #{encoded_content_nomatch}
      --#{marker}
      EOF



      # Define the message action
      body =<<~HTML
      Content-Type: text/html; charset=UTF-8

      #{message}
      --#{marker}--
      HTML


      msg = head + match_attach + nomatch_attach + body


      begin
        Net::SMTP.start('relay.eni.pri', 25) do |smtp|
          smtp.send_message msg, from, to
        end
        # p "Email Inviata"
      rescue Exception => e
        print  e
      end
    end
  end

end

