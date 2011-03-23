# encoding: UTF-8
module Streamer
  module Output
    def output
      return if item_queue.empty?
      insert do
        while item = item_queue.shift
          c = color_of(item)
          puts item.u.c(c)
        end
      end
    end

    def insert
      clear_line
      yield if block_given?
      print @ps
    #ensure
      #Readline.refresh_line
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
  end

  extend Output
end
