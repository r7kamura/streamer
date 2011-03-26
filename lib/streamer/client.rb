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
      @item_queue = []
      _init

      @ps = "♪ ".c(33)
      EventMachine::run do
        every_hour_stream = {
          :interval   => 1,
          :action_if  => lambda { Time.now.to_i % 3600 == 0 },
          :action     => lambda { sync { item_queue << {:debug => true, :text => "#{Time.now}"} } },
        } # For sample of stream
        streams << input_stream
        streams << output_stream
        streams << every_hour_stream
        streams << stream_2ch("http://kamome.2ch.net/test/read.cgi/anime/1301070713/")
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
              ap e.backtrace
            end
          end
        end
      end
    end

    def stop
      EventMachine.stop_event_loop
    end
  end

  extend Client
end

