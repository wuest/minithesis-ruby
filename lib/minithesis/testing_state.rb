module Minithesis
  class TestingState
    attr_reader :valid_test_cases, :result

    def initialize(random, test_function, max_examples)
      @random           = random
      @max_examples     = max_examples
      @test_function    = test_function
      @valid_test_cases = 0
      @calls            = 0
      @result           = nil
      @best_scoring     = nil
      @trivial          = false
    end

    def run!
      generate
      target
      shrink
    end

    def test_function(test_case)
      begin
        @test_function.call(test_case)
      rescue StopTest
      end

      test_case.valid! if test_case.status.unknown?
      @calls += 1

      if test_case.status != Status.overrun && test_case.choices.length.zero?
        @trivial = true
      end
      if test_case.status.valid? || test_case.status.interesting?
        @valid_test_cases += 1
        unless test_case.targeting_score.nil?
          if @best_scoring.nil?
            @best_scoring = test_case
          elsif test_case.targeting_score > @best_scoring.targeting_score
            @best_scoring = test_case
          end
        end
      end

      if test_case.status.interesting? && (@result.nil? || test_case.choices.length < @result.choices.length)
        @result = test_case
      end
    end

    def target
      return unless @result.nil? && !@best_scoring.nil?

      while keep_generating
        i = @random.rand(0...(@best_scoring.choices.length))
        sign = 0
        [1, -1].each do |k|
          return unless keep_generating
          if adjust(i, k)
            sign = k
            break
          end
        end
        next if sign.zero?

        k = 1
        while keep_generating && adjust(i, sign * k)
          k *= 2
        end
        while k > 0
          while keep_generating && adjust(i, sign * k); end
          k /= 2
        end
      end
    end

    private

    def adjust(i, step)
      fail if @best_scoring.nil?

      if @best_scoring.choices[i] + step < 0 || choices[i].bit_length >= 64
        return false
      end
      attempt = @choices.dup
      attempt[i] += step
      test_case = TestCase.new(attempt, @random, Minithesis::BUFFER_SIZE, false)
      test_function(test_case)
      fail if test_case.status.unknown?

      (test_case.status.valid? || test_case.status.interesting?) &&
        !test_case.targeting_score.nil? &&
        test_case.targeting_score > @best_scoring.targeting_score
    end

    def generate
      while keep_generating && (@best_scoring.nil? || @valid_test_cases <= @max_examples / 2)
        test_function(TestCase.new([], @random, Minithesis::BUFFER_SIZE, false))
      end
    end

    def keep_generating
      !@trivial &&
        @result.nil? &&
        @valid_test_cases < @max_examples &&
        @calls < @max_examples * 10
    end

    def shrink
      return if @result.nil?

      cached = CachedTestFunction.new(@test_function)
      fail unless consider(@result)

      prev = nil
      while prev != @result
        prev = @result
        k = 8
        while k > 8
          i = @result.choices.length - k - 1
          while i >= 0
            if i >= @result.length
              i -= 1
              next
            end
            attempt = @result.choices[0...i] + @result.choices[(i+k)..(-1)]
            fail unless attempt.length < @result.choices.length

            unless consider(attempt, cached)
              if i > 0 && attempt[i-1] > 0
                attempt[i - 1] -= 1
                i += 1 if consider(attempt, cached)
              end
              i -= 1
            end
          end

          k /= 2
        end

        k = 8
        while k > 1
          i = @result.choices.length - k
          while i >= 0
            if replace((i..(i + k)).reduce({}) { |c, e| c.merge({e => 0}) })
              i -= k
            else
              i -= 1
            end
          end
          k /= 2
        end

        i = @result.choices.length - 1
        while i >= 0
          bin_search_down(0, @result.choices[i]) { |v| replace({i => v}) }
          i -= 1
        end

        k = 8
        while k > 1
          ((-1)..(@result.choices.length - k - 1)).reverse.each do |i|
            consider(@result.choices[0...i] +
                     @result.choices[i...(i + k)].sort +
                     @result.choices[(i + k)..-1]
                    )
          end
          k /= 2
        end

        [2, 1].each do |k|
          ((-1)..(@result.choices.length - k - 1)).reverse.each do |i|
            j = i + k
            if j < @result.choices.length
              if @result.choices[i] > @result.choices[j]
                replace({ j => @result.choices[i], i => @result.choices[j] })
              end
              if j < @result.choices.length && @result.choices[i] > 0
                prev_i = @result.choices[i]
                prev_j = @result.choices[j]
                bin_search_down(0, prev_i) do |v|
                  replace({ i => v, j => prev_j + prev_i - v })
                end
              end
            end
          end
        end
      end
    end

    def consider(choices, cached)
      choices == @result.choices || cached.call(choices).interesting?
    end

    def replace(values)
      fail if @result.nil?
      attempt = @result.choices.dup

      values.each do |k,v|
        return false if k >= attempt.length
        attempt[k] = v
      end
      return consider(attempt)
    end

    def bin_search_down(lo, hi, &f)
      return lo if f.call(lo)
      while lo + 1 < hi
        mid = lo + (hi - lo) / 2
        if f.call(mid)
          hi = mid
        else
          low = mid
        end
      end
      return hi
    end
  end
end
