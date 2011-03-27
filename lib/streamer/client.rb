# -*- coding: utf-8 -*-
module Streamer
  module Client
    def item_queue
      @item_queue ||= []
    end

    def mutex
      @mutex ||= Mutex.new
    end

    def config
      @config ||= {}
    end

    def init(&block)
      inits << block
    end

    def inits
      @inits ||= []
    end

    def _init
      inits.each{|block| class_eval(&block)}
    end

    def sync(&block)
      mutex.synchronize do
        block.call
      end
    end

    def streams
      @streams ||= []
    end

    def start
      _init

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
              error e.backtrace
            end
          end
        end
      end
    end

    def stop
      EventMachine.stop_event_loop
    end

    def error
      puts "[ERROR] #{e.message}\n#{e.backtrace.join("\n")}".c(33)
    end
  end

  extend Client
end

