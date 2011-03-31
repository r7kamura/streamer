# -*- coding: utf-8 -*-
module Streamer
  module Core
    def config;     @config     ||= {}        end
    def inits;      @inits      ||= []        end
    def item_queue; @item_queue ||= []        end
    def streams;    @streams    ||= []        end
    def mutex;      @mutex      ||= Mutex.new end
    def onces;      @once       ||= []        end

    def once(&block)
      onces << block
    end

    def _once
      onces.each { |block| class_eval(&block) }
    end

    def init(&block)
      inits << block
    end

    def _init
      load_config
      inits.each{|block| class_eval(&block)}
      restore_history
    end

    def sync(&block)
      mutex.synchronize { block.call }
    end

    def async(&block)
      Thread.start(&block)
    end

    def start
      _init
      _once

      @ps = "♪ ".c(33)
      EventMachine::run do
        streams.each do |stream|
          Thread.start do
            begin
              stream[:once].call if stream[:once]
              loop do
                if stream[:action_if].nil? || stream[:action_if].call
                  stream[:action].call
                  sleep stream[:interval]
                end
              end
            rescue => e
              error e
            end
          end
        end
      end
    end

    def stop
      EventMachine.stop_event_loop
      store_history
    end

    def error(e)
      case e.class.to_s
      when "SocketError"
        puts "[ERROR] Network error".c(31)
      else
        puts "[ERROR] #{e.class}\n#{e.message}\n#{e.backtrace.join("\n")}".c(31)
      end
    end

    def load_config
      config[:dir]              ||= File.expand_path(ARGV[0] || '~/.streamer')
      config[:plugin_dir]       ||= File.join(config[:dir], 'plugin')
      config[:file]             ||= File.join(config[:dir], 'config')

      [config[:dir], config[:plugin_dir]].each do |dir|
        FileUtils.mkdir_p(dir) unless File.exists?(dir)
      end

      if File.exists?(config[:file])
        load config[:file]
      else
        File.open(config[:file], 'w')
      end
    end

    def store_history
      history_size = config[:history_size] || 1000
      File.open(File.join(config[:dir], 'history'), 'w') do |file|
        lines = Readline::HISTORY.to_a[([Readline::HISTORY.size - history_size, 0].max)..-1]
        file.print(lines.join("\n"))
      end
    end

    def restore_history
      history_file = File.join(config[:dir], 'history')
      if File.exists?(history_file)
        File.read(history_file).split(/\n/).each { |line| Readline::HISTORY << line }
      end
    end
  end

  extend Core
end

