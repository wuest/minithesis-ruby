module Minithesis
  class TestCase
    attr_reader :choices, :status, :targeting_score

    def self.for_choices(choices, print_results)
      self.new(choices, nil, choices.length, print_results)
    end

    def initialize(prefix, random, max_size, print_results)
      @prefix          = prefix
      @random          = random
      @max_size        = max_size
      @choices         = []
      @status          = Status.unknown
      @print_results   = print_results
      @depth           = 0
      @targeting_score = nil
    end

    def valid!
      @status = Status.valid
    end

    def choice(n)
      result = make_choice(n) { @random.rand(0..n) }

      puts "choice(#{n}): #{result}" if @print_results
      result
    end

    def weighted(p)
      result = if p <= 0
                 forced_choice(0)
               elsif p >= 1
                 forced_choice(1)
               else
                 make_choice(1) { (@random.rand <= p) ? 1 : 0 }
               end
      puts "weighted(#{p}): #{result}" if @print_results
      result
    end

    def forced_choice(n)
      raise RangeError("Out of range: #{n}") if n.bit_length > 64 || n < 0
      raise Frozen unless @status.unknown?
      mark_status(Status.overrun) if @choices.length > @max_size
      @choices << n
      n
    end

    def make_choice(n, &f)
      raise RangeError("Out of range: #{n}") if n.bit_length > 64 || n < 0
      raise Frozen unless @status.unknown?
      mark_status(Status.overrun) if @choices.length > @max_size

      result = if @choices.length < @prefix.length
                 @prefix[@choices.length]
               else
                 f.call
               end
      @choices << result
      mark_status(Status.invalid) if result > n
      result
    end

    def reject!
      mark_status(Status.invalid)
    end

    def assume(precondition)
      reject! unless precondition
    end

    def target(score)
      @targeting_score = score
    end

    def any(possibility)
      @depth += 1
      result = possibility.produce(self)

      puts "any(#{possibility}): #{result}"
      result
    ensure
      @depth -= 1
    end

    def mark_status(status)
      raise Frozen unless @status.unknown? || @status == status
      @status = status
      raise StopTest
    end
  end
end
