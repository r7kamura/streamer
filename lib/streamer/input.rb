# encoding: UTF-8
module Streamer
  module Input
    def input(buf)
      item_queue.push buf unless buf.empty?
    end
  end

  extend Input
end
