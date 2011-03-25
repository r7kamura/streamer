#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "awesome_print"
require "eventmachine"
require "readline"

module Streamer
  require "streamer/client"
  require "streamer/commands"
  require "streamer/ext"
  require "streamer/input"
  require "streamer/output"
  require "streamer/2ch"
end
