#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "rubygems"
require "awesome_print"
require "eventmachine"
require "readline"

module Streamer
  require "streamer/client"
  require "streamer/input"
  require "streamer/output"
  require "streamer/ext"
end
