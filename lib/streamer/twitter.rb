# NOTE: It's important to cache duped objects
module Streamer
  module Twitter
    attr_reader :twitter

    def connect_twitter
      start_stream(:host  => 'userstream.twitter.com', :path  => '/2/user.json', :ssl => true)
    end

    def start_stream(options)
      stop_stream

      options = {
        :oauth => config.slice(:consumer_key, :consumer_secret).merge(
          :access_key     => config[:token],
          :access_secret  => config[:secret],
        )
      }.merge(options)

      EM.next_tick {
        begin
          @stream = ::Twitter::JSONStream.connect(options)
          @stream.each_item { |item| item_queue << JSON.parse(item).merge({:type => :twitter}) }
          @stream.on_error { |message| puts "error: #{message}" }
          @stream.on_reconnect { |timeout, retries| puts "reconnecting in: #{timeout} seconds" }
          @stream.on_max_reconnects { |timeout, retries| notify "Failed after #{retries} failed reconnects" }
          puts_items twitter.home_timeline
        rescue EventMachine::ConnectionError, Errno::ECONNREFUSED => e
          error e
        end
      }
    end

    def stop_stream
      @stream.stop if @stream
    end

    def get_access_token
      puts "get access token..."
      consumer = OAuth::Consumer.new(
        self.config[:consumer_key],
        self.config[:consumer_secret],
        :site => 'https://api.twitter.com',
      )
      request_token = consumer.get_request_token

      puts "1) open: #{request_token.authorize_url}"
      Launchy::Browser.run(request_token.authorize_url) rescue nil

      begin
        print "2) Enter the PIN: "
        pin = STDIN.gets.strip
        access_token = request_token.get_access_token(:oauth_verifier => pin)
      rescue OAuth::Unauthorized => e
        error e
        retry
      rescue Errno::ECONNRESET => e
        error e
      end
      config[:token] = access_token.token
      config[:secret] = access_token.secret

      puts "Saving 'token' and 'secret' to '#{config[:file]}'"
      File.open(config[:file], 'a') do |f|
        f << "Streamer.config[:token] = '#{config[:token]}'"
        f << "\n"
        f << "Streamer.config[:secret] = '#{config[:secret]}'"
      end
    end

    def async_twitter(&block)
      async { handle_api_error(&block) }
    end

    def handle_api_error(&block)
      result = block.call
      puts "[ERROR] #{result["error"]}".c(31) if result["error"]
    end
  end

  init do
    next unless config[:twitter]

    config[:consumer_key]     ||= 'grQ0RQoR0hjUtLrVPdHdw'
    config[:consumer_secret]  ||= 'qAw9xeOlBEfPdjYEc278otBMCwPLW0bbPxUDChI'
    @twitter = TwitterOAuth::Client.new(config.slice(:consumer_key, :consumer_secret, :token, :secret))
    get_access_token unless self.config[:token] && self.config[:secret]
    connect_twitter
    notify_filters << twitter.info["screen_name"]

    output do |item|
      next if item["text"].nil?

      info = []
      if item["in_reply_to_status_id"]
        info << "(Re:#{obj2id(item["in_reply_to_status_id"])})"
      elsif item["retweeted_status"]
        info << "(RT: #{obj2id(item["retweeted_status"]["id"])})"
      end

      text = item["text"].u
      text.gsub!("\n", " ")
      text.gsub!(/@([0-9A-Za-z_]+)/) {|i| i.c(color_of($1)) }
      text.gsub!(/(?:^#([^\s]+))|(?:\s+#([^\s]+))/) {|i| i.c(color_of($1 || $2)) }
      text.gsub!(URI.regexp(["http", "https"])) {|i| i.c(4).c(36) }
      text += "[P]".c(31) if item["user"]["protected"]
      text = item["_indent"] + text if item["_indent"]

      puts [
        Time.parse(item["created_at"]).strftime("%H:%M"),
        obj2id(item["id"]).c(90),
        ("%-18s" % item["user"]["screen_name"][0..17]).c(color_of(item["user"]["screen_name"])),
        text,
        info.join(' - ').c(90),
      ].join(" ")

      notify_filters.each do |word|
        notify(item["text"], {:title => item["user"]["screen_name"]}) if item["text"].include?(word)
      end
    end

    output do |item|
      next unless item["event"]

      result = [
        Time.now.strftime("%H:%M"),
        " "*3,
        ("%-18s" % item["source"]["screen_name"][0..17]).c(color_of(item["source"]["screen_name"])),
      ]
      case item["event"]
      when "follow", "block", "unblock"
        result << "[#{item["event"]}]".c(42) + "  => #{item["target"]["screen_name"]}"
      when "favorite", "unfavorite"
        result << "[#{item["event"]}]".c(42) + "  => #{item["target"]["screen_name"]} : #{item["target_object"]["text"].u}"
      when "delete"
        result << "[deleted]".c(42) + " #{item["delete"]["status"]["id"]}"
      end

      text = result.join(" ")
      puts text
      text_notify = item["source"]["screen_name"]
      text_notify += (" => " + item["target_object"]["text"].u) if item["target_object"]
      notify(text_notify, {:title => item["event"]})
    end

    command :recent, :help => "show recent tweets" do
      puts_items twitter.home_timeline
    end

    command :tw, :help => "tweet (ex => 'tw hello world now!!')" do |m|
      async_twitter { twitter.update(m[1]) } if confirm("update '#{m[1]}'")
    end

    command :mentions, :help => "show tweets menioned(replyed) to me" do
      puts_items twitter.mentions
    end

    command :follow, :help => "follow specified twitter user" do |m|
      async_twitter { twitter.friend(m[1]) }
    end

    command :unfollow, :help => "unfollow specified twitter user" do |m|
      async_twitter { twitter.unfriend(m[1]) }
    end

    command :user do |m|
      ap twitter.show(m[1]).slice(*%w(id screen_name name profile_image_url description url location time_zone lang protected))
    end

    command :search do |m|
      puts_items twitter.search(m[1])["results"].each { |s|
        s["user"] = {"screen_name" => s["from_user"]}
        s["_disable_cache"] = true
        words = m[1].split(/\s+/).reject{|x| x[0] =~ /^-|^(OR|AND)$/ }.map{|x|
          case x
          when /^from:(.+)/, /^to:(.+)/
            $1
          else
            x
          end
        }
        s["_highlights"] = words
      }
    end

    command %r|^:retweet\s+(\d+)$|, :as => :retweet do |m|
      target = twitter.status(m[1])
      if confirm("retweet 'RT @#{target["user"]["screen_name"]}: #{target["text"]}'")
        async_twitter { twitter.retweet(m[1]) }
      end
    end

    command %r|^:retweet\s+(\d+)\s+(.*)$|, :as => :retweet do |m|
      target = twitter.status(m[1])
      text = "#{m[2]} RT @#{target["user"]["screen_name"]}: #{target["text"]} (#{target["id"]})"
      if confirm("unofficial retweet '#{text}'")
        async_twitter { twitter.update(text) }
      end
    end

    command %r|^:reply (\d+)\s+(.*)|, :as => :reply do |m|
      in_reply_to_status_id = m[1]
      target = twitter.status(in_reply_to_status_id)
      screen_name = target["user"]["screen_name"]
      text = "@#{screen_name} #{m[2]}"
      if confirm(["'@#{screen_name}: #{target["text"]}'", "reply '#{text}'"].join("\n"))
        async_twitter { twitter.update(text, :in_reply_to_status_id => in_reply_to_status_id) }
      end
    end

    command :favorite do |m|
      async_twitter { twitter.favorite(m[1]) }
    end

    command :unfavorite do |m|
      async_twitter { twitter.unfavorite(m[1]) }
    end

    command :retweeted_by_me do
      puts_items twitter.retweeted_by_me
    end

    command :retweeted_to_me do
      puts_items twitter.retweeted_to_me
    end

    command :retweets_of_me do
      puts_items twitter.retweets_of_me
    end

    command :block do |m|
      async_twitter { twitter.block(m[1]) }
    end

    command :unblock do |m|
      async_twitter { twitter.unblock(m[1]) }
    end

    command :report_spam do |m|
      async_twitter { twitter.report_spam(m[1]) }
    end

    command :messages do
      puts_items twitter.messages.each { |s|
        s["user"] = {"screen_name" => s["sender_screen_name"]}
        s["_disable_cache"] = true
      }
    end

    command :delete do |m|
      tweet = twitter.status(m[1])
      async_twitter { twitter.status_destroy(m[1]) } if confirm("delete '#{tweet["text"]}'")
    end

    command %r|^:message (\w+)\s+(.*)|, :as => :message do |m|
      async_twitter { twitter.message(*m[1, 2]) } if confirm("message '#{m[2]}' to @#{m[1]}")
    end

    command :tree, :help => "show tweets tree by replies" do |m|
      tree = [twitter.status(m[1])]
      while reply = tree.last["in_reply_to_status_id"]
        tree << twitter.status(reply)
      end
      puts_items tree.reverse_each.with_index {|tweet, indent|
        tweet["_indent"] = "  " * indent
      }
    end

    command :notify, :help => "add word to notify_filter (notify when tweet includes the word)" do |m|
      notify_filters << m[1] unless notify_filters.include?(m[1])
      ap notify_filters
    end

    command :notify_filters, :help => "show notify_filters" do
      ap notify_filters
    end

    command :notify_delete, :help => "delete word in notify_filter (ex. ':notify_delete 3')" do |m|
      notify_filters.delete_at(m[1].to_i)
      ap notify_filters
    end
  end

  once do
    class ::TwitterOAuth::Client
      [:status, :info].each do |m|
        define_method("#{m}_with_cache") do |*args|
          key = "#{m}:#{args.join(',')}"
          if result = Streamer.cache.read(key)
            result.dup
          else
            result = __send__(:"#{m}_without_cache", *args)
            Streamer.cache.write(key, result.dup)
            result
          end
        end
        alias_method_chain m, :cache
      end
    end
  end

  extend Twitter
  argv << [:t, :twitter, "Add twitter stream"]
  argv << [:p, :proxy, "specify proxy server", :optional => true]
end


module TwitterOAuth
  class Client
    private
    def consumer
      @consumer ||= OAuth::Consumer.new(
        @consumer_key,
        @consumer_secret,
        { :site => 'https://api.twitter.com', :proxy => @proxy }
      )
    end
  end
end
