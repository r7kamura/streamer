# encoding: UTF-8
module Streamer
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

    command :debug, :help => "show debug info" do
      ap command_names
      ap commands
    end

    command :eval, :help => "exexute Ruby commands" do |m|
      ap eval(m[1])
    end
  end
end
