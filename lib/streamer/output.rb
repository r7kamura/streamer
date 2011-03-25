# encoding: UTF-8
module Streamer
  module Output
    def outputs
      @outputs ||= []
    end

    # register / execute
    def output(&block)
      if block
        outputs << block
      else
        return if item_queue.empty?
        insert do
          while item = item_queue.shift
            begin
              outputs.each{|o| o.call(item)}
            rescue => e
              ap e
            end
          end
        end
      end
    end

    def insert
      clear_line
      yield if block_given?
      print @ps
    end

    def clear_line
      print "\e[0G" + "\e[K"
    end

    def colors
      config[:colors] ||= (31..36).to_a + (91..96).to_a
    end

    def color_of(identifier)
      colors[identifier.to_i(36) % colors.size]
    end

    def output_stream
      {
        :interval   => 1,
        :action_if  => lambda { Readline.line_buffer.nil? || Readline.line_buffer.empty? },
        :action     => lambda { sync { output } },
      }
    end
  end

  init do
    output do |item|
      if item[:twitter]
        puts "T: #{item[:text]}".c(31)
      elsif item[:debug]
        puts "D: #{item[:text]}".c(32)
      else
        puts item[:text].gsub(/>>\d+/){|anchor| anchor.c(32)}
      end
    end
  end

  extend Output
end
