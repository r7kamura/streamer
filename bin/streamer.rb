#!/usr/bin/env ruby

$:.unshift(File.expand_path("../../lib", __FILE__)) if $0 == __FILE__
require "rubygems"
require "slop"
require "streamer"

opts = Slop.parse! :help => true do
  banner "Usage: streamer [options]"
  Streamer.argv.each { |arg| on(*arg) }
end

options = opts.to_hash(true)
options.delete(:help)

Streamer.start(options)
