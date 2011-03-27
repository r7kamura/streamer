# -*- coding: utf-8 -*-
module Streamer
  module Core
    def config;     @config     ||= {}        end
    def inits;      @inits      ||= []        end
    def item_queue; @item_queue ||= []        end
    def streams;    @streams    ||= []        end
    def mutex;      @mutex      ||= Mutex.new end

    def init(&block)
      inits << block
    end

    def _init
      inits.each{|block| class_eval(&block)}
    end

    def sync(&block)
      mutex.synchronize { block.call }
    end

    def async(&block)
      Thread.start(&block)
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
              error e
            end
          end
        end
      end
    end

    def stop
      EventMachine.stop_event_loop
    end

    def error(e)
      puts "[ERROR] #{e.message}\n#{e.backtrace.join("\n")}".c(31)
    end
  end

  extend Core
end

