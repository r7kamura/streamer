# encoding: UTF-8
module Streamer
  module NiChannel
    def stream_2ch(url)
      {
        :interval   => 5,
        :once       => lambda {
          @thread_data = ThreadData.new(url)
          push_text(@thread_data.subject.c(33))
        },
        :action     => lambda { load_thread },
      }
    end

    def colorize_anchor(text)
      text.gsub(/>>\d+/){|anchor| anchor.c(32)}
    end

    def prettify_line(line, is_aa=false)
      text  = is_aa ? "AA(ry" : colorize_anchor(line[:body].gsub("\n", " "))
      num   = line[:n].to_s.c(31)
      "%-4s: %s" % [num, text]
    end

    def load_thread
      if @thread_data.length >= 1000
        @thread_data.guess_next_thread.first(3).each do |thread|
          push_text("%s\n    %s" % [thread[:subject], thread[:uri]])
        end
      else
        begin
          @thread_data.retrieve.last(10).each do |line|
            push_text(prettify_line(line, line.aa?))
          end
        rescue Exception => e
          error e
        end
      end
    end
  end

  init do
    command :thread, :help => "change watching URL of 2ch" do |m|
      @thread_data = ThreadData.new(m[1])
      puts "Now watching '#{m[1]}'"
    end

    command :ch, :help => "force to load 2ch" do
      puts "loading 2ch..."
      load_thread
    end

    command :res, :help => "show 2ch post of specified number" do |m|
      line = @thread_data[m[1].to_i]
      puts prettify_line(line, line.aa?)
    end

    streams << stream_2ch('http://kamome.2ch.net/test/read.cgi/anime/1301250531/')
  end

  extend NiChannel
end



require 'uri'
require 'net/http'
require 'stringio'
require 'zlib'
require 'nkf'
require 'kconv'
$KCODE = "u" if RUBY_VERSION < "1.9" # json use this

class ThreadData
  class UnknownThread < StandardError; end

  attr_accessor :uri
  attr_accessor :last_modified, :size

  Line = Struct.new(:n, :name, :mail, :misc, :body, :opts, :id) do
    def aa?
      body = self.body
      return false if body.count("\n") < 3

      significants = body.scan(/[>\n0-9a-z０-９A-Zａ-ｚＡ-Ｚぁ-んァ-ン一-龠]/u).size.to_f
      body_length  = body.scan(/./u).size
      is_aa = 1 - significants / body_length
      is_aa > 0.6
    end
  end

  def initialize(thread_uri)
    @uri = URI(thread_uri)
    _, _, _, @board, @num, = *@uri.path.split('/')
    @dat = []
  end

  def length
    @dat.length
  end

  def subject
    retrieve(true) if @dat.size.zero?
    self[1].opts || ""
  end

  def [](n)
    l = @dat[n - 1]
    return nil unless l
    name, mail, misc, body, opts = * l.split(/<>/)
    id = misc[/ID:([^\s]+)/, 1]

    body.gsub!(/<br>/, "\n")
    body.gsub!(/<[^>]+>/, "")
    body.gsub!(/^\s+|\s+$/, "")
    body.gsub!(/&(gt|lt|amp|nbsp);/) {|s|
      { 'gt' => ">", 'lt' => "<", 'amp' => "&", 'nbsp' => " " }[$1]
    }

    Line.new(n, name, mail, misc, body, opts, id)
  end

  def dat
    @num
  end

  def request(force)
    @dat = [] if @force
    Net::HTTP.start(@uri.host, @uri.port) do |http|
      req = Net::HTTP::Get.new('/%s/dat/%d.dat' % [@board, @num])
      req['User-Agent']       = 'Monazilla/1.00 (2ig.rb/0.0e)'
      req['Acceept-Encoding'] = @size ? 'identify' : 'gzip'
      unless force
        req['If-Modified-Since'] = @last_modified if @last_modified
        req['Range']             = "bytes=%d-" % @size if @size
      end
      http.request(req)
    end
  end

  def retrieve(force=false)
    res = request(force)

    case res.code.to_i
    when 200, 206
      body = res.body
      if res['Content-Encoding'] == 'gzip'
        body = StringIO.open(body, 'rb') {|io| Zlib::GzipReader.new(io).read }
      end

      @last_modified = res['Last-Modified']
      if res.code == '206'
        @size += body.size
      else
        @size  = body.size
      end

      body = NKF.nkf('-w', body)

      curr = @dat.size + 1
      @dat.concat(body.split(/\n/))
      last = @dat.size

      (curr..last).map {|n| self[n]}
    when 416 # たぶん削除が発生
      p ['416']
      retrieve(true)
      []
    when 304 # Not modified
      []
    when 302 # dat 落ち
      p ['302', res['Location']]
      raise UnknownThread
    else
      p ['Unknown Status:', res.code]
      []
    end
  end

  def canonicalize_subject(subject)
    subject.gsub(/[Ａ-Ｚａ-ｚ０-９]/u) {|c|
      c.unpack("U*").map {|i| i - 65248 }.pack("U*")
    }
  end

  def guess_next_thread
    res = Net::HTTP.start(@uri.host, @uri.port) do |http|
      req = Net::HTTP::Get.new('/%s/subject.txt' % @board)
      req['User-Agent']        = 'Monazilla/1.00 (2ig.rb/0.0e)'
      http.request(req)
    end

    recent_posted_threads = (900..999).inject({}) {|r,i|
      line = self[i]
      line.body.scan(%r|ttp://#{@uri.host}/test/read.cgi/[^/]+/\d+/|).each do |uri|
        r["h#{uri}"] = i
      end if line
      r
    }

    current_subject    = canonicalize_subject(self.subject)
    current_thread_rev = current_subject.scan(/\d+/).map {|d| d.to_i }
    current            = current_subject.scan(/./u)

    body = NKF.nkf('-w', res.body)
    threads = body.split(/\n/).map {|l|
      dat, rest = *l.split(/<>/)
      dat.sub!(/\.dat$/, "")

      uri = "http://#{@uri.host}/test/read.cgi/#{@board}/#{dat}/"

      subject, n = */(.+?) \((\d+)\)/.match(rest).captures
                      canonical_subject = canonicalize_subject(subject)
                      thread_rev     = canonical_subject[/\d+/].to_i

                      distance       = (dat     == self.dat)     ? Float::MAX :
                        (subject == self.subject) ? 0 :
                        levenshtein(canonical_subject.scan(/./u), current)
                      continuous_num = current_thread_rev.find {|rev| rev == thread_rev - 1 }
                      appear_recent  = recent_posted_threads[uri]

                      score = distance
                      score -= 10 if continuous_num
                      score -= 10 if appear_recent
                      score += 10 if dat.to_i < self.dat.to_i
                      {
                        :uri            => uri,
                        :dat            => dat,
                        :subject        => subject,
                        :distance       => distance,
                        :continuous_num => continuous_num,
                        :appear_recent  => appear_recent,
                        :score          => score.to_f
                      }
    }.sort_by {|o|
      o[:score]
    }

    threads
  end

  def levenshtein(a, b)
    case
    when a.empty?
      b.length
    when b.empty?
      a.length
    when a == b
      0
    else
      d = Array.new(a.length + 1) { |s|
        Array.new(b.length + 1, 0)
      }

      (0..a.length).each do |i|
        d[i][0] = i
      end

      (0..b.length).each do |j|
        d[0][j] = j
      end

      (1..a.length).each do |i|
        (1..b.length).each do |j|
          cost = (a[i - 1] == b[j - 1]) ? 0 : 1
          d[i][j] = [
            d[i-1][j  ] + 1,
            d[i  ][j-1] + 1,
            d[i-1][j-1] + cost
          ].min
        end
      end

      d[a.length][b.length]
    end
  end
end


