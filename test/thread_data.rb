require File.join(File.expand_path(File.dirname(__FILE__)), "test_helpers")
require "streamer"

class ThreadDataTest < ActiveSupport::TestCase
  test "use ThreadData" do
    assert ThreadData
  end

  test "create ThreadData" do
    valid_2ch_uri = "http://kamome.2ch.net/test/read.cgi/anime/1301148231"
    assert_instance_of ThreadData, ThreadData.new(valid_2ch_uri)
    assert_instance_of ThreadData, ThreadData.new(valid_2ch_uri + "/")
  end
end
