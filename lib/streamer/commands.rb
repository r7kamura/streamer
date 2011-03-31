# encoding: UTF-8
module Streamer
  # register default commands
  init do
    command :exit, :help => "exit streamer" do
      stop
    end

    command :restart, :help => "restart streamer" do
      puts "restarting..."
      stop
      exec File.expand_path('../../../bin/streamer.rb', __FILE__)
    end

    command :help, :help => "show help" do
      puts helps.sort.join("\n")
    end

    command :eval, :help => "execute Ruby command" do |m|
      begin
        ap eval(m[1])
      rescue Exception => e
        error e
      end
    end

    command :config, :help => "open config directory" do
      system("open #{config[:dir]}")
    end

    command :'!' do |m|
      system m[1]
    end
  end
end
