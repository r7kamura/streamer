# encoding: UTF-8
module Streamer
  module Hatebu
    def hatebu_stream(username)
      {
        :interval   => 60 * 5,
        :once       => lambda { @hatebu_data = HatebuData.new(username) },
        :action     => lambda { push_bookmarks },
      }
    end

    def push_bookmarks
      sync {
        @hatebu_data.retrieve.each do |b|
          item_queue << {
            :text => "%s %s %s %s\n  %s" % [
              Time.now.strftime("%H:%M"),
              ("%-12s" % b[:user]).c(36),
              ("%5s"   % b[:count]).to_s.c(31),
              b[:text],
              b[:link].c(90),
            ]
          }
        end
      }
    end
  end

  init do
    streams << hatebu_stream("r7kamura")

    command :hatebu, :help => "force to reload hatebu" do
      push_bookmarks
    end
  end

  extend Hatebu
end

require "mechanize"
class HatebuData
  attr_accessor :username, :loaded_ids

  def initialize(username)
    @username = username
    @agent = Mechanize.new
    @loaded_ids = []
  end

  def retrieve
    begin
      page = @agent.get(URI.parse("http://b.hatena.ne.jp/#{@username}/favorite"))
      parse(page)
    rescue => e
      error e
      return
    end
  end

  def parse(page)
    results = []
    page.search("#bookmarked_user > li").first(10).reverse.each do |item|
      id = item["data-eid"]
      next if @loaded_ids.include?(id)
      @loaded_ids << id
      link = item.at("h3 a.entry-link")
      results << {
        :text  => link.text,
        :link  => link[:href],
        :user  => item.at("ul.comment li.others .username").text,
        :count => item.at("ul li.users a").text.to_i,
      }
    end
    results
  end

end

