#!/usr/bin/env ruby
# Encoding: utf-8
# warn_indent: true
# frozen_string_literal: true

require 'rufus-scheduler'
require 'logger'
require 'open3'

    $logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG
# $logger.level = Logger::WARN
# STDOUT.sync = true
# STDERR.sync = true

$logger.formatter = proc do |severity, datetime, _progname, msg|
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
end

ENV["TZ"] = "UTC"

class Handler
  attr_reader :actions

  def initialize(actions: nil)
    @actions = actions
  end

  def call(job)
    begin
      # $logger.info "#{job} at #{Time.now}"
      start_task
    rescue Rufus::Scheduler::TimeoutError
     $logger.warn "Sono andato in Timeout"
    end
  end

  def start_task
      @actions.each do |action|
        $logger.debug "Start task #{action}:"
        break unless process_is_ok(action)
        $logger.debug " - finito corretamente"
      end
  end

  def process_is_ok(action)
    exit_status, err, out = start_process(action)

    if (out != nil) &&  (out != "")
      $logger.info "  - #{out.strip}"
    end

    if (exit_status != 0) && (exit_status != 2)
    
        $logger.warn err.chomp
        p "Invio email"
        # Email.send(err, action, controparte)
      # else
      #   # $logger.info " nessun file da archiviare"
      # end
      return false
    end
    return true
  end

  def start_process(action)
    cmd = "#{RbConfig.ruby} main.rb --interface=scheduler --enviroment=production #{action} "
    stdout, stderr, wait_thr = Open3.capture3(cmd)
    return  wait_thr.exitstatus, stderr, stdout
  end

end

# @todo diminuire la frequenza di rufus-scheduler
scheduler = Rufus::Scheduler.new(:frequency => "1h")

def scheduler.on_error(job, error)
  $logger.warn("intercepted error in #{job.id}: #{error.message}")
end

task = Handler.new(actions: ["download", "archivia"])

scheduler.every('8h', task, :timeout => '5m', :tag  => 'task')

puts "Start Scheduler"

scheduler.join
