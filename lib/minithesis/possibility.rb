module Minithesis
  class Possibility
    def initialize(name = nil, &produce)
      @produce = produce
      @name    = name || produce.source_location
    end

    def inspect
      @name
    end

    def map(&f)
      self
        .class
        .new("#{@name}.map(#{f.source_location})") { |t| f.call(t.any(self)) }
    end

    def bind(&f)
      self.class.new("#{@name}.bind(#{f.source_location})") do |t|
        t.any(f.call(t.any(self)))
      end
    end

    def satisfying(&f)
      self
        .class
        .new("#{@name}.select(#{f.source_location})") do |t|
          3.times do
            candidate = t.any(self)
            return candidate if f.call(candidate)
          end
          t.reject!
        end
    end

    def produce(t)
      @produce.call(t)
    end
  end
end
