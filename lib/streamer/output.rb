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
  end

  # 複数のoutputに分けてる理由はそんなにない
  init do
    output do |item|
      next unless item[:twitter]
      puts item[:text].c(33)
    end
    output do |item|
      next unless item[:debug]
      puts item[:text].c(34)
    end
  end

  extend Output
end
