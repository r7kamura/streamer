# encoding: UTF-8
module Streamer
  module Output
    def outputs;        @outputs        ||= [] end
    def output_filters; @output_filters ||= [] end

    def output_filter(&block)
      output_filters << block
    end

    # register / execute
    def output(&block)
      if block
        outputs << block
      else
        return if item_queue.empty?
        insert do
          while item = item_queue.shift
            puts_item(item)
          end
        end
      end
    end

    def puts_items(items)
      [items].flatten.reverse_each do |item|
        next if output_filters.any? { |f| f.call(item) == false }
        outputs.each do |o|
          begin
            o.call(item)
          rescue => e
            error e
          end
        end
      end
    end

    def insert
      clear_line
      yield if block_given?
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

    def push_text(text)
      sync { item_queue << { :text => text } }
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
    streams << output_stream

    output {|item| puts item[:text] unless item[:text].nil? || item[:text].empty?  }
  end

  extend Output
end
