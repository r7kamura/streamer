# encoding: UTF-8
module Streamer
  module Input
    def commands
      @commands ||= []
    end

    def command_names
      @command_names ||= []
    end

    def helps
      @helps ||= []
    end

    def completions
      @completions ||= []
    end

    def completion(&block)
      completions << block
    end

    def input(text)
      begin
        if command = command(text)
          command[:block].call(command[:pattern].match(text))
        elsif !text.empty?
          puts "Command not found".c(31)
        end
      rescue Exception => e
        ap e
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
      if Readline.line_buffer =~ /^\s*#{Regexp.quote(text)}/
        command_names.grep /^#{Regexp.quote(text)}/ # $~で代替した方がきっと速い
      end
    end
  end

  extend Input
end
