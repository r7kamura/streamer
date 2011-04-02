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
    config[:consumer_key]     ||= 'RmzuwQ5g0SYObMfebIKJag'
    config[:consumer_secret]  ||= 'V98dYYmWm9JoG7qfOF0jhJaVEVW3QhGYcDJ9JQSXU'
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

    command :recent do
      puts_items twitter.home_timeline
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
