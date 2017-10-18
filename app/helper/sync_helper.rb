#!/usr/bin/env ruby
# Encoding: utf-8
# warn_indent: true
# frozen_string_literal: true

module SyncHelper

  def sync(type: nil)

    def robocop_exist?
      (try! {run("which robocopy")}).map { |ctx|
        msg     = ctx[0]
        trovato = ctx[1]
        trovato.success? ? Success("Trovato robocopy: " + msg) : Failure("robocopy non trovato")
      }
    end

    def get_sync_folder
      directory = Transmission::Config.path.sync
      if File.directory?(directory)
        Success(directory)
      else
        Failure("Directory sync non trovata")
      end
    end

    def cmd_comand(type, sync_folder)
      case type
      when 'fetch' then Success("robocopy /njh /njs /ndl /nc /ns /np /nfl /mir #{sync_folder} #{download_path} ")
      when 'push'  then Success("robocopy /mir #{download_path} #{sync_folder}")
      else
        Failure("Type non riconosciuto")
      end
    end

    def avvio(cmd)
      (try! {run(cmd)}).map { |ctx|
        msg    = ctx[0]
        status = ctx[1]
        (status.exitstatus < 7) ? Success(0) : Failure("Problema nella sincronizzazione dei file con robocopy: \n"+msg)
      }
    end

    result = in_sequence do
      and_then          { robocop_exist?                        }
      get(:sync_folder) { get_sync_folder                       }
      get(:cmd)         { cmd_comand(type, sync_folder)         }
      and_then          { avvio(cmd)                            }
      and_yield         { Success("Sincronizzato corretamente") }
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
      return stdout.strip, status
    end
  end

end
