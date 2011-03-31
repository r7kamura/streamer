module Streamer
  module Cache
    attr_reader :cache
  end

  init do
    @cache ||= config[:cache] || ActiveSupport::Cache::MemoryStore.new
  end

  extend Cache
end
