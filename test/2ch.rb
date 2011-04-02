require File.join(File.expand_path(File.dirname(__FILE__)), "test_helpers")
require "streamer"

class HatebuTest < ActiveSupport::TestCase
  test "create thread_data" do
    assert_instance_of ThreadData, ThreadData.new("http://kamome.2ch.net/test/read.cgi/anime/1301312578/")
  end
end
