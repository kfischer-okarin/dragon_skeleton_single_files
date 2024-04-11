# MIT License
#
# Copyright (c) 2023-2024 Kevin Fischer
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

# Contains pathfinding algorithms.
#
# Graphs are represented as hashes where keys are nodes and values are arrays of edges.
# Edges are hashes with keys +:to+ and +:cost+. +:to+ is the node the edge
# leads to and +:cost+ is the cost of traversing the edge.
#
# Nodes can be any kind of data, usually coordinates on a grid with additional pathfinding related data.
#
# Example:
#
#   graph = {
#     { x: 0, y: 0 } => [
#       { to: { x: 1, y: 0 }, cost: 1 },
#       { to: { x: 0, y: 1 }, cost: 1 }
#     ],
#     { x: 1, y: 0 } => [
#       { to: { x: 0, y: 0 }, cost: 1 },
#       { to: { x: 0, y: 1 }, cost: 1.5 }
#     ],
#     { x: 0, y: 1 } => [
#       { to: { x: 0, y: 0 }, cost: 1 },
#       { to: { x: 1, y: 0 }, cost: 1.5 }
#     ]
#   }
module Pathfinding
  # Calculates the {Manhattan distance}[https://en.wikipedia.org/wiki/Taxicab_geometry] between the two arguments.
  #
  # The arguments must be hashes with keys +:x+ and +:y+.
  MANHATTAN_DISTANCE = ->(a, b) { (a[:x] - b[:x]).abs + (a[:y] - b[:y]).abs }

  # Calculates the {Chebyshev distance}[https://en.wikipedia.org/wiki/Chebyshev_distance] between the two arguments.
  #
  # The arguments must be hashes with keys +:x+ and +:y+.
  CHEBYSHEV_DISTANCE = ->(a, b) { [(a[:x] - b[:x]).abs, (a[:y] - b[:y]).abs].max }

  # Calculates the {Euclidean distance}[https://en.wikipedia.org/wiki/Euclidean_distance] between the two arguments.
  #
  # The arguments must be hashes with keys +:x+ and +:y+.
  EUCLIDEAN_DISTANCE = ->(a, b) { Math.sqrt((a[:x] - b[:x])**2 + (a[:y] - b[:y])**2) }
end

module Pathfinding
  # Pathfinder using the A* algorithm.
  class AStar
    # Creates a new A* pathfinder with the given graph and heuristic.
    #
    # [graph] The graph to search. See the explanation in Pathfinding for more
    #         details about the data structure.
    # [heuristic] A proc that takes two nodes and returns the heuristic value.
    #             Commonly used distance functions are defined as constants in Pathfinding
    #             (e.g. Pathfinding::MANHATTAN_DISTANCE).
    def initialize(graph, heuristic:)
      @graph = graph
      @heuristic = heuristic
    end

    # Finds a path from the start node to the goal node.
    #
    # Returns an array of nodes that form the path from the start node to the goal node.
    # If no path is found, an empty array is returned.
    def find_path(start, goal)
      frontier = PriorityQueue.new
      came_from = { start => nil }
      cost_so_far = { start => 0 }
      frontier.insert start, 0

      until frontier.empty?
        current = frontier.pop
        break if current == goal

        @graph[current].each do |edge|
          cost_to_neighbor = edge[:cost]
          total_cost_to_neighbor = cost_so_far[current] + cost_to_neighbor
          neighbor = edge[:to]
          next if cost_so_far.include?(neighbor) && cost_so_far[neighbor] <= total_cost_to_neighbor

          heuristic_value = @heuristic.call(neighbor, goal)
          priority = total_cost_to_neighbor + heuristic_value
          frontier.insert neighbor, priority
          came_from[neighbor] = current
          cost_so_far[neighbor] = total_cost_to_neighbor
        end
      end
      return [] unless came_from.key? goal

      result = []
      current = goal
      until current.nil?
        result.unshift current
        current = came_from[current]
      end
      result
    end
  end
end

module Pathfinding
  class PriorityQueue # :nodoc: Internal use by AStar only
    def initialize
      @data = [nil]
    end

    def insert(element, priority)
      @data << { element: element, priority: priority }
      heapify_up(@data.size - 1)
    end

    def pop
      result = @data[1]&.[](:element)
      last_element = @data.pop
      unless empty?
        @data[1] = last_element
        heapify_down(1)
      end
      result
    end

    def empty?
      @data.size == 1
    end

    def clear
      @data = [nil]
    end

    private

    def heapify_up(index)
      return if index == 1

      parent_index = index.idiv 2
      return if @data[index][:priority] >= @data[parent_index][:priority]

      swap(index, parent_index)
      heapify_up(parent_index)
    end

    def heapify_down(index)
      smallest_child_index = smallest_child_index(index)

      return unless smallest_child_index

      return if @data[index][:priority] < @data[smallest_child_index][:priority]

      swap(index, smallest_child_index)
      heapify_down(smallest_child_index)
    end

    def swap(index1, index2)
      @data[index1], @data[index2] = [@data[index2], @data[index1]]
    end

    def smallest_child_index(index)
      left_index = index * 2
      left_value = @data[left_index]
      right_index = (index * 2) + 1
      right_value = @data[right_index]

      return nil unless left_value || right_value
      return left_index unless right_value
      return right_index unless left_value

      left_value[:priority] < right_value[:priority] ? left_index : right_index
    end
  end
end

