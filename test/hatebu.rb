require File.join(File.expand_path(File.dirname(__FILE__)), "test_helpers")
require "streamer"

class HatebuTest < ActiveSupport::TestCase
  test "create HatebuData" do
    assert_instance_of HatebuData, HatebuData.new("r7kamura")
  end

  test "parse" do
    hd = HatebuData.new("r7kamura")
    page1 = Mechanize.new.get(URI.parse("http://b.hatena.ne.jp/#{hd.username}/favorite"))
    page2 = Mechanize.new.get(URI.parse("http://b.hatena.ne.jp/#{hd.username}/favorite"))
    assert_instance_of Array, items = hd.parse(page1)
    assert_instance_of Array, items = hd.parse(page2)
    assert_not_nil items.first
    assert_equal items.first, nil
  end
end
