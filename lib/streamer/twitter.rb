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
        rescue EventMachine::ConnectionError => e
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
        :site => 'http://api.twitter.com'
      )
      request_token = consumer.get_request_token

      puts "1) open: #{request_token.authorize_url}"
      Launchy::Browser.run(request_token.authorize_url)

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
  end

  init do
    config[:consumer_key]     ||= 'grQ0RQoR0hjUtLrVPdHdw'
    config[:consumer_secret]  ||= 'qAw9xeOlBEfPdjYEc278otBMCwPLW0bbPxUDChI'
    @twitter = TwitterOAuth::Client.new(config.slice(:consumer_key, :consumer_secret, :token, :secret))
    get_access_token unless self.config[:token] && self.config[:secret]

    output do |item|
      next if item["text"].nil? || item["_disable_cache"]
      Streamer.cache.write("status:#{item["id"]}", item)

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

      puts [
        Time.parse(item["created_at"]).strftime("%H:%M"),
        obj2id(item["id"]).c(90),
        ("%-18s" % item["user"]["screen_name"][0..17]).c(color_of(item["user"]["screen_name"])),
        text,
        info.join(' - ').c(90),
      ].join(" ")
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

      puts result.join(" ")
    end

    command :recent, :help => "show recent tweets" do
      puts_items twitter.home_timeline
    end

    command :tw, :help => "tweet (ex => 'tw hello world now!!')" do |m|
      async { twitter.update(m[1]) } if confirm("update '#{m[1]}'")
    end

    command :mentions, :help => "show tweets menioned(replyed) to me" do
      puts_items twitter.mentions
    end

    command :follow, :help => "follow specified twitter user" do |m|
      async { twitter.friend(m[1]) }
    end

    command :unfollow, :help => "unfollow specified twitter user" do |m|
      async { twitter.unfriend(m[1]) }
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
      if confirm("retweet 'RT @#{target["user"]["screen_name"]}: #{target["text"].e}'")
        async { twitter.retweet(m[1]) }
      end
    end

    command %r|^:retweet\s+(\d+)\s+(.*)$|, :as => :retweet do |m|
      target = twitter.status(m[1])
      text = "#{m[2]} RT @#{target["user"]["screen_name"]}: #{target["text"].e} (#{target["id"]})"
      if confirm("unofficial retweet '#{text}'")
        async { twitter.update(text) }
      end
    end

    command :favorite do |m|
      async { twitter.favorite(m[1]) }
    end

    command :unfavorite do |m|
      async { twitter.unfavorite(m[1]) }
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
      async { twitter.block(m[1]) }
    end

    command :unblock do |m|
      async { twitter.unblock(m[1]) }
    end

    command :report_spam do |m|
      async { twitter.report_spam(m[1]) }
    end

    command :messages do
      puts_items twitter.messages.each { |s|
        s["user"] = {"screen_name" => s["sender_screen_name"]}
        s["_disable_cache"] = true
      }
    end

    command %r|^:message (\w+)\s+(.*)|, :as => :message do |m|
      async { twitter.message(*m[1, 2]) } if confirm("message '#{m[2]}' to @#{m[1]}")
    end

    connect_twitter
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
end
