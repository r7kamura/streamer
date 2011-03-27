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

    command :eval, :help => "exexute Ruby commands" do |m|
      begin
        ap eval(m[1])
      rescue Exception => e
        error e
      end
    end
  end
end
