#!/usr/bin/env ruby
# Encoding: utf-8
# warn_indent: true
# frozen_string_literal: true

module S3Helper

  def s3_sync(type: nil)

    def aws_exist?
      (try! {run("which aws")}).map { |ctx|
        msg     = ctx[0]
        trovato = ctx[1]
        trovato ? Success("Trovato aws: " + msg) : Failure("aws non trovato devi installare aws-cli")
      }
    end

    def cmd_comand(type)
      case type
      when 'fetch' then Success("aws s3 sync s3://#{bucket} #{download_path} --only-show-errors")
      when 'push'  then Success("aws s3 sync #{download_path} s3://#{bucket} --delete --only-show-errors")
      else
        Failure("Type non riconosciuto")
      end
    end

    def avvio(cmd)
      (try! {run(cmd)}).map { |ctx|
        msg    = ctx[0]
        status = ctx[1]
        status ? Success(0) : Failure("Problema nella sincronizzazione dei file con S3: \n"+msg)
      }
    end

    result = in_sequence do
      and_then    { aws_exist?         }
      get(:cmd)   { cmd_comand(type)   }
      and_then    { avvio(cmd)           }
      and_yield   { Success("Sincronizzato corretamente")          }
    end

    if result.failure?
      print result.value
      exit!
    end
  end

  def run(cmd)
    try! do
      logger.debug("run: "+cmd)
      stdout, status = Open3.capture2e(cmd)
      return stdout.strip, status.success?
    end
  end

  def bucket
     bucket ||= Transmission::Config.s3.bucket
  end

end
