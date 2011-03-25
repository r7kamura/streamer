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
        every_minute_stream = {
          :interval   => 1,
          :action_if  => lambda { Time.now.to_i % 60 == 0 },
          :action     => lambda { sync { item_queue << {:debug => true, :text => "#{Time.now}"} } },
        } # For sample of stream
        streams << input_stream
        streams << output_stream
        streams << every_minute_stream
        streams.each do |stream|
          Thread.start do
            loop do
              begin
                if stream[:action_if].nil? || stream[:action_if].call
                  stream[:action].call
                  sleep stream[:interval]
                end
              rescue => e
                ap e
              end
            end
          end
        end
      end
    end

    def stop
      EventMachine.stop_event_loop
      puts
    end
  end

  extend Client
end

