# encoding: UTF-8
module Streamer
  init do
    command :exit do
      puts :stop
    end

    command :help do
      puts "help!!!!!!".c(33)
    end

    command :debug do
      ap command_names
      ap commands
    end

    command :eval do |m|
      ap eval(m[1])
    end
  end
end
