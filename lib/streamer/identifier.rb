module Streamer
  module Identifier
    attr_accessor :identifier

    def obj2id(obj)
      identifier.obj2id(obj)
    end

    def id2obj(obj)
      identifier.id2obj(obj)
    end

    # convert id($aa,$ab,...) <=> obj(any objects)
    class Gen
      def initialize(ids = ('aa'..'zz').to_a, prefix = '$')
        if not ids.kind_of?(Array)
          raise ArgumentError, 'args should be an Array'
        elsif ids.empty?
          raise ArgumentError, 'args should not be empty'
        end
        @ids = ids.map { |id| prefix + id }
        @id2obj = {}
        @obj2id = {}
        @prefix = prefix
      end

      def id2obj(id)
        @id2obj[id]
      end

      def obj2id(obj)
        @obj2id[obj] || self.next(obj)
      end

      def next(obj)
        @ids.push << id = @ids.shift
        @obj2id.delete(@id2obj[id])
        @id2obj[id]   = obj
        @obj2id[obj]  = id
      end
    end
  end

  init do
    self.identifier ||= Identifier::Gen.new
  end

  extend Identifier
end
