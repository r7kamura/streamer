#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "active_support/cache"
require "active_support/core_ext"
require "ap"
require "json"
require "launchy"
require "mechanize"
require "notify"
require "oauth"
require "readline"
require "thread"
require "twitter/json_stream"
require "twitter_oauth"

module Streamer
  require "streamer/core"
  require "streamer/commands"
  require "streamer/ext"
  require "streamer/input"
  require "streamer/output"
  require "streamer/2ch"
  require "streamer/hatebu"
  require "streamer/twitter"
  require "streamer/identifier"
  require "streamer/cache"
end

Thread.abort_on_exception = true
