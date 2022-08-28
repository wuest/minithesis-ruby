require 'minithesis/cached_test_function'
require 'minithesis/fs_database'
require 'minithesis/possibility'
require 'minithesis/test_case'
require 'minithesis/testing_state'

module Minithesis
  BUFFER_SIZE = 8 * 1024

  class Status
    def message
      ''
    end

    class Interesting < Status
      def initialize(choices)
        @_choices = choices
      end

      def message
        @_choices.inspect
      end
    end

    class Invalid < Status
    end

    class Overrun < Status
    end

    class Unknown < Status
    end

    class Valid < Status
    end

    invalid = Invalid.new.freeze
    overrun = Overrun.new.freeze
    unknown = Unknown.new.freeze
    valid = Valid.new.freeze

    define_singleton_method(:invalid)     { invalid }
    define_singleton_method(:overrun)     { overrun }
    define_singleton_method(:unknown)     { unknown }
    define_singleton_method(:valid)       { valid }
    define_singleton_method(:interesting) { |msg| Interesting.new(msg).freeze }

    def invalid?
      self.is_a?(Invalid)
    end

    def overrun?
      self.is_a?(Overrun)
    end

    def unknown?
      self.is_a?(Unknown)
    end

    def valid?
      self.is_a?(Valid)
    end

    def interesting?
      self.is_a?(Interesting)
    end

    def initialize
      raise 'Use singleton instances'
    end
  end

  class Frozen < FrozenError
  end

  class StopTest < RuntimeError
  end

  class Unsatisfiable < RuntimeError
  end

  def self.integers(m, n)
    Possibility.new("integers(#{m}, #{n})") { |t| m + t.choice(n - m) }
  end

  def self.just(val)
    Possibility.new("just(#{val})") { |t| val }
  end

  def self.nothing
    Possibility.new('nothing') { |t| t.reject }
  end

  def self.mix_of(*ps)
    return nothing if ps.empty?

    Possibility.new("mix_of(#{ps.map(&:name).join(', ')})") do |t|
      t.any(ps[t.choice(ps.length - 1)])
    end
  end

  def self.array(*ps)
    Possibility.new("array(#{ps.map(&:name).join(', ')})") do |t|
      ps.map(&t.method(:any))
    end
  end

  def self.run_test(max = 100, random = Random.new, db = nil, quiet = false)
    ->(test) do
      mark_failures_interesting = ->(tc) do
        begin
          test.call(tc)
        rescue
          raise if tc.status.unknown?
          tc.mark_status(Status.interesting(tc.choices))
        end
      end

      state = TestingState.new(random, mark_failures_interesting, max)

      db ||= FSDatabase.new('.minithesis-cache')

      previous_failure = db[test.source_location]

      unless previous_failure.nil?
        choices = []
      end

      state.run! if state.result.nil?
      raise Unsatisfiable if state.valid_test_cases.zero?
      if state.result.nil?
        begin
          db.delete(test.source_location)
        rescue KeyError
        end
      else
        db[test.source_location] = state.result
      end

      unless state.result.nil?
        test.call(TestCase.for_choices(state.result, !quiet))
      end
      state
    end
  end
end
