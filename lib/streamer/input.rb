# encoding: UTF-8
module Streamer
  module Input
    def command_names;  @command_names  ||= [] end
    def commands;       @commands       ||= [] end
    def completions;    @completions    ||= [] end
    def helps;          @helps          ||= [] end
    def input_filters;  @input_filters  ||= [] end

    def input_filter(&block)
      input_filters << block
    end

    def completion(&block)
      completions << block
    end

    def input(text)
      return if text.empty?
      begin
        input_filters.each { |f| text = f.call(text) }
        if command = command(text)
          command[:block].call(command[:pattern].match(text))
        elsif !text.empty?
          puts "Command not found".c(31)
        end
        store_history
      rescue Exception => e
        error e
      end
    end

    # register command / get command
    def command(pattern, options = {}, &block)
      if block
        if pattern.is_a?(String) || pattern.is_a?(Symbol)
          command_name = ":#{pattern}"
          command_names << command_name
          if block.arity > 0
            pattern = %r|^#{command_name}\s+(.*)$|
          else
            pattern = %r|^#{command_name}$|
          end
        end
        helps         << "%-20s %s" % [command_name, options[:help]] if options[:help] && command_name
        command_names << ":#{options[:as]}" if options[:as]
        commands      << {:pattern => pattern, :block => block}
      else
        commands.detect {|c| c[:pattern] =~ pattern}
      end
    end

    def input_stream
      {
        :interval   => 0,
        :action_if  => lambda { @buf = Readline.readline(@ps, true) },
        :action     => lambda {
          Readline::HISTORY.pop if @buf.empty?
          sync { input @buf.strip }
        },
      }
    end

    def confirm(message, type = :y)
      message = message.c(36)
      case type
      when :y
        print "#{message} [Yn] "
        return !(gets.strip =~ /^n$/i)
      when :n
        print "#{message} [yN] "
        return !!(gets.strip =~ /^y$/i)
      else
        raise "type must be :y or :n"
      end
    end
  end

  init do
    streams << input_stream

    Readline.completion_proc = lambda do |text|
      completions.inject([]) do |results, completion|
        begin
          results + (completion.call(text) || [])
        rescue Exception => e
          error e
          results
        end
      end
    end

    completion do |text|
      regexp = /^#{Regexp.quote(text)}/
      results = []
      results += command_names.grep(regexp)
      range = Readline::HISTORY.count >= 100 ? -100..-1 : 0..-1
      results += Readline::HISTORY.to_a[range].map { |line| line.split(/\s+/) }.flatten.grep(regexp)
      results
    end

    input_filter do |text|
      if text =~ %r|^:|
        text.gsub(/\$\w+/) { |id| id2obj(id) || id }
      else
        text
      end
    end
  end

  extend Input
end
