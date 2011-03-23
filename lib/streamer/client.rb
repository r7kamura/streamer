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

    def run
      @item_queue = []

      @ps = "X / _ / X < ".c(33)
      EventMachine::run do
        Thread.start do
          while buf = Readline.readline(@ps, true)
            Readline::HISTORY.pop if buf.empty?
            sync { input buf.strip }
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
      end
    end

    def sync(&block)
      mutex.synchronize do
        block.call
      end
    end
  end

  extend Client
end

