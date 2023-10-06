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

# A Tilemap manages a grid of tiles and renders them to the screen.
#
# Example:
#
#   args.state.tilemap ||= Tilemap.new(x: 0, y: 0, cell_w: 16, cell_h: 16, grid_w: 40, grid_h: 25)
#   args.state.tilemap[0, 0].path = 'sprites/tiles/stone_floor.png'
#   args.state.tilemap[1, 0].path = 'sprites/tiles/stone_wall.png'
#   # ...
#
#   args.state.tilemap.render(args.outputs)
class Tilemap
  # The x coordinate of the bottom left corner of the tilemap
  attr_accessor :x
  # The y coordinate of the bottom left corner of the tilemap
  attr_accessor :y
  # The width of each cell in the tilemap
  attr_reader :cell_w
  # The height of each cell in the tilemap
  attr_reader :cell_h
  # The width of the tilemap in cells
  attr_reader :grid_w
  # The height of the tilemap in cells
  attr_reader :grid_h

  # Creates a new tilemap.
  #
  # You can optionally pass a tileset to use for the tilemap.
  #
  # A tileset is an object that responds to the following methods:
  #
  # [+default_tile+] Returns a Hash with default values for each cell
  #
  # [+[]+] Receives a tile key as argument and returns a Hash with values for the
  #        given tile
  def initialize(x:, y:, cell_w:, cell_h:, grid_w:, grid_h:, tileset: nil)
    @x = x
    @y = y
    @cell_w = cell_w
    @cell_h = cell_h
    @grid_h = grid_h
    @grid_w = grid_w
    @tileset = tileset
    @cells = grid_h.times.flat_map { |grid_y|
      grid_w.times.map { |grid_x|
        Cell.new(grid_x * cell_w, grid_y * cell_h, tileset: tileset)
      }
    }
    @primitive = RenderedPrimitive.new(@cells, self)
  end

  # Returns the width of the tilemap in pixels.
  def w
    @grid_w * @cell_w
  end

  # Returns the height of the tilemap in pixels.
  def h
    @grid_h * @cell_h
  end

  # Returns the Cell at the given grid coordinates.
  def [](x, y)
    @cells[y * @grid_w + x]
  end

  # Renders the tilemap to the given outputs / render target.
  def render(outputs)
    outputs.primitives << @primitive
  end

  # Converts a position to grid coordinates.
  def to_grid_coordinates(position)
    {
      x: (position.x - @x).idiv(@cell_w),
      y: (position.y - @y).idiv(@cell_h)
    }
  end

  # Returns the rectangle of the cell at the given grid coordinates.
  def cell_rect(grid_coordinates)
    {
      x: @x + (grid_coordinates.x * @cell_w),
      y: @y + (grid_coordinates.y * @cell_h),
      w: @cell_w,
      h: @cell_h
    }
  end

  class RenderedPrimitive # :nodoc: Internal class responsible for rendering the tilemap.
    def initialize(cells, tilemap)
      @cells = cells
      @tilemap = tilemap
    end

    def primitive_marker
      :sprite
    end

    def draw_override(ffi_draw)
      origin_x = @tilemap.x
      origin_y = @tilemap.y
      w = @tilemap.cell_w
      h = @tilemap.cell_h
      cell_count = @cells.size
      cells = @cells
      index = 0

      while index < cell_count
        x, y, path, r, g, b, a, tile_x, tile_y, tile_w, tile_h = cells[index]
        ffi_draw.draw_sprite_4 origin_x + x, origin_y + y, w, h,
                               path,
                               nil, # angle
                               a, r, g, b,
                               tile_x, tile_y, tile_w, tile_h,
                               nil, nil, # flip_horizontally, flip_vertically
                               nil, nil, # angle_anchor_x, angle_anchor_y
                               nil, nil, nil, nil, # source_x, source_y, source_w, source_h
                               nil # blendmode_enum

        index += 1
      end
    end
  end
end

class Tilemap
  # A single cell in a tilemap.
  #
  # A cell is an Array with the following values which are also available as
  # attributes:
  #
  # - \[0\] +x+ (read-only)
  # - \[1\] +y+ (read-only)
  # - \[2\] +path+
  # - \[3\] +r+
  # - \[4\] +g+
  # - \[5\] +b+
  # - \[6\] +a+
  # - \[7\] +tile_x+
  # - \[8\] +tile_y+
  # - \[9\] +tile_w+
  # - \[10\] +tile_h+
  # - \[11\] +tile+: The key of the tile to use for this cell
  #
  # If the Tilemap has a tileset, setting the +tile+ attribute will also update the
  # other attributes according to the values returned by the tileset.
  class Cell < Array
    def self.index_accessors(*names) # :nodoc: Internal method used to define accessors for the cell values.
      @property_indexes = {}
      names.each_with_index do |name, index|
        @property_indexes[name] = index
        define_method(name) { self[index] }
        define_method("#{name}=") { |value| self[index] = value }
      end
    end

    # Returns the index of the given property.
    def self.property_index(name)
      @property_indexes[name]
    end

    index_accessors :x, :y, :path, :r, :g, :b, :a, :tile_x, :tile_y, :tile_w, :tile_h, :tile

    undef_method :x=
    undef_method :y=

    def initialize(x, y, tileset: nil) # :nodoc: The user should not create cells directly.
      super(12)

      self[0] = x
      self[1] = y
      return unless tileset

      assign(tileset.default_tile)
      tile_index = Cell.property_index(:tile)
      define_singleton_method(:tile=) do |tile|
        return unless self[tile_index] != tile

        assign(tileset[tile])
        self[tile_index] = tile
      end
    end

    # Assigns the given values to the cell.
    #
    # Example:
    #
    #   cell.assign(path: 'sprites/box.png', r: 255, g: 0, b: 0)
    def assign(values)
      values.each do |name, value|
        index = Cell.property_index(name)
        next unless index

        self[index] = value
      end
    end
  end
end

