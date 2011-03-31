# NOTE: It's important to cache duped objects
module Streamer
  module Twitter
    attr_reader :twitter

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
      item = item.dup
      item.keys.select { |key| key =~ /^_/ }.each { |key| item.delete(key) } # remote optional data like "_stream", "_highlights"
      Streamer.cache.write("status:#{item["id"]}", item)
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
end
