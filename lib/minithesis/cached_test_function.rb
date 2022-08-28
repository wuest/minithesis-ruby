module Minithesis
  class CachedTestFunction
    def initialize(test_function)
      @test_function = test_function
      @tree = {}
    end

    def call(choices)
      node = @tree
      begin
        choices.each do |c|
          node = node.fetch(c)
          if node.is_a?(Status)
            fail if node.overrun?
            return node
          end
        end
        return Status.overrun
      rescue KeyError
      end

      test_case = TestCase.for_choices(choices)
      @test_function.call(test_case)
      fail if test_case.status.unknown?

      node = @tree
      test_case.choices.each_with_id do |i, c|
        if i + 1 < test_case.choices.length || test_case.status.overrun?
          begin
            node = node.fetch(c)
          rescue KeyError
          end
        else
          node[c] = test_case.status
        end
      end
      return test_case.status
    end
  end
end
