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

    def run
      @item_queue = []
      _init

      @ps = "( ◕ ‿‿ ◕ ) ".c(33)
      EventMachine::run do
        Thread.start do
          while text = Readline.readline(@ps, true)
            Readline::HISTORY.pop if text.empty?
            sync { input text.strip }
          end
        end

        Thread.start do
          loop do
            if Readline.line_buffer.nil? || Readline.line_buffer.empty?
              sync { output }
            end
            sleep 1
          end
        end

        Thread.start do
          loop do
            item_queue << {:twitter => true, :text => "#{Time.now}"}
            sleep 5
          end
        end
      end
    end

    def stream_2ch
    end

    def sync(&block)
      mutex.synchronize do
        block.call
      end
    end
  end

  extend Client
end

