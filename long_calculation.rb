# MIT License
# 
# Copyright (c) 2023 Kevin Fischer
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Contains methods for defining and running long calculations that can be spread over multiple ticks.
#
# Define a calculation with the LongCalculation.define method.
#
#   calculation = LongCalculation.define do
#     result = 0
#     1_000_000.times do |i|
#       result += compute_something(i)
#       LongCalculation.finish_step
#     end
#     result
#   end
#
# It will be interrupted every time the LongCalculation.finish_step method is called during the calculation
# and will be resumed the next time the LongCalculationFiber#resume method is called on the calculation.
#
#   calculation.resume
#
# Once finished, the result can be accessed with the LongCalculationFiber#result method.
#
#   result = calculation.result
#
# The calculation can also be run completely with the LongCalculationFiber#finish method. Or to run as many
# steps as possible in a given amount of milliseconds, use the LongCalculationFiber#run_for_ms method.
module LongCalculation
  class << self
    # Define a long calculation with many steps and returns it as a
    # LongCalculationFiber.
    def define
      fiber = Fiber.new do
        result = yield
        Fiber.current.result = result
      end
      fiber.extend LongCalculationFiber
      fiber
    end
    # Call this inside a long calculation to signify that one step of the calculation
    # has finished.
    #
    # The calculation will be resumed the next time the
    # LongCalculationFiber#resume method is called on the calculation.
    def finish_step
      return unless inside_calculation?
      Fiber.yield
    end
    # Returns +true+ if the current code is running inside a long calculation.
    def inside_calculation?
      Fiber.current.respond_to? :result
    end
  end
end

module LongCalculation
  # A long calculation that runs over many steps and eventually returns a result.
  module LongCalculationFiber
    def self.extend_object(object) # :nodoc:
      raise ArgumentError, "Fiber expected, got #{object.class}" unless object.is_a? Fiber
      state = {}
      object.define_singleton_method :result do
        state[:result]
      end
      object.define_singleton_method :result= do |value|
        state[:result] = value
      end
      super
    end
    # Runs the next step of the calculation.
    def resume
      super unless finished?
    end
    # Returns +true+ if the calculation has finished.
    def finished?
      !result.nil?
    end
    # Runs the calculation until it finishes.
    def finish
      resume until finished?
    end
    # Runs the calculation until it finishes or the given amount of milliseconds has passed.
    #
    # This is useful for spreading the calculation over multiple ticks.
    def run_for_ms(milliseconds)
      start_time = Time.now.to_f
      resume until finished? || (Time.now.to_f - start_time) * 1000 >= milliseconds
    end
    ##
    # :attr_accessor: result
    # The result of the calculation or +nil+ if the calculation has not finished yet.
  end
end
