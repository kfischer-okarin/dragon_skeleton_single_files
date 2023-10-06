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

# Provides a simple functional style animation system.
#
# In the simplest case, a frame is a hash of values to be set on the target and a
# duration:
#
#   animation = Animations.build(
#     frames: [
#       { tile_x: 0, tile_y: 0, duration: 5 },
#       { tile_x: 32, tile_y: 0, duration: 5 }
#     ]
#   )
#
# It can then be started via ::start! on a target (e.g. a sprite):
#
#   sprite = { x: 100, y: 100, w: 32, h: 32, tile_w: 32, tile_h: 32, path: 'resources/character.png' }
#   animation_state = Animations.start! sprite, animation: animation
#
# and every tick you need to call ::perform_tick to advance the animation:
#
#   Animations.perform_tick animation_state
#
# By default the animation will stay on a frame until the duration is reached,
# then immediately move to the next frame but you can also specify an easing
# function to gradually interpolate between frames:
#
#   animation = Animations.build(
#     frames: [
#       { x: 0, y: 0, duration: 5, easing: :linear },
#       { x: 100, tile_y: 100, duration: 5, easing: :linear }
#     ]
#   )
module Animations
  class << self
    # Creates and starts a one-time animation that will interpolate between
    # the current values of the target and the values in the +to+ hash.
    #
    # Returns an animation state that can be passed to ::perform_tick.
    def lerp(target, to:, duration:)
      first_frame_values = {}.tap { |frame|
        to.each_key do |key|
          frame[key] = target[key]
        end
      }
      animation = build(
        frames: [
          first_frame_values.merge!(duration: duration, easing: :linear),
          to.dup
        ]
      )
      start! target, animation: animation, repeat: false
    end

    # Builds an animation from a list of frames.
    #
    # Each frame is a hash of values that will be set on
    # the target when the frame becomes active except for
    # the following reserved keys:
    #
    # [:duration] The number of ticks the frame will be active for.
    #
    #             This value is required except for the last frame
    #             of a non-repeating animation.
    #
    # [:metadata] A hash of metadata that is available via
    #             ::current_frame_metadata when the frame is active.
    #
    # [:easing] The easing function to use when interpolating between
    #           the current and next frame.
    #
    #           Check out the EASING_FUNCTIONS constant for a list of
    #           available easing functions.
    def build(frames:)
      {
        frames: frames.map { |frame|
          {
            duration: frame[:duration],
            metadata: frame[:metadata],
            easing: frame[:easing] || :none,
            values: frame.except(:duration, :metadata, :easing)
          }
        }
      }
    end

    # Starts an animation on a target and returns an animation state which can be
    # used to advance the animation via ::perform_tick.
    #
    # By default the animation will repeat indefinitely but this can be disabled
    # by setting <code>repeat: false</code>.
    def start!(target, animation:, repeat: true)
      {
        animation: animation,
        target: target,
        frame_index: 0,
        ticks: 0,
        repeat: repeat,
        finished: false
      }.tap { |animation_state|
        update_target animation_state
      }
    end

    # Advances the animation by one tick.
    def perform_tick(animation_state)
      next_tick animation_state
      update_target animation_state
    end

    # Returns the metadata associated with the active frame of the animation.
    def current_frame_metadata(animation_state)
      current_frame(animation_state)[:metadata]
    end

    # Returns +true+ if the animation has finished.
    def finished?(animation_state)
      animation_state[:finished]
    end

    private

    def next_tick(animation_state)
      return if finished? animation_state

      frames = animation_state[:animation][:frames]

      animation_state[:ticks] += 1
      return unless animation_state[:ticks] >= frames[animation_state[:frame_index]][:duration]

      animation_state[:ticks] = 0
      animation_state[:frame_index] = (animation_state[:frame_index] + 1) % frames.length
      return unless animation_state[:frame_index] == frames.length - 1 && !animation_state[:repeat]

      animation_state[:finished] = true
    end

    def update_target(animation_state)
      animation_state[:target].merge! current_frame_values(animation_state)
    end

    def current_frame_values(animation_state)
      frame = current_frame(animation_state)
      return frame[:values] if frame[:easing] == :none

      factor = EASING_FUNCTIONS[frame[:easing]].call(animation_state[:ticks] / frame[:duration])
      next_frame_values = next_frame(animation_state)[:values]
      {}.tap { |values|
        frame[:values].each do |key, value|
          values[key] = ((next_frame_values[key] - value) * factor + value).round
        end
      }
    end

    def current_frame(animation_state)
      animation_state[:animation][:frames][animation_state[:frame_index]]
    end

    def next_frame(animation_state)
      frames = animation_state[:animation][:frames]
      frames[(animation_state[:frame_index] + 1) % frames.length]
    end
  end

  # Easing functions for interpolating between frames.
  #
  # Following easing functions are provided but you can also add your own to this hash:
  #
  # [:linear] rdoc-image:../images/easing_linear.png
  EASING_FUNCTIONS = {
    linear: ->(t) { t }
  }
end

module FileFormats # :nodoc:
  # Contains methods for reading Aseprite JSON Data files as produced by the
  # "Export Sprite Sheet" command.
  #
  # The Data file must have been exported as *Array* with *Tags* and *Slices*
  # enabled.
  #
  # Tag names will be converted to symbols during reading.
  #
  # Frame durations will be rounded down to the nearest 3 ticks (50ms).
  module AsepriteJson
    class << self
      # Reads an Aseprite Spritesheet JSON data file and returns a hash of
      # animations which can be used with the DragonSkeleton::Animations or
      # DragonSkeleton::AnimatedSprite modules.
      def read_as_animations(json_path)
        sprite_sheet_data = deep_symbolize_keys! $gtk.parse_json_file(json_path)

        path = sprite_path(sprite_sheet_data, json_path)

        {}.tap { |result|
          frames = sprite_sheet_data.fetch :frames
          slices_data = sprite_sheet_data.fetch(:meta).fetch :slices

          sprite_sheet_data.fetch(:meta).fetch(:frameTags).each do |frame_tag_data|
            tag = frame_tag_data.fetch(:name).to_sym
            frame_range = frame_tag_data.fetch(:from)..frame_tag_data.fetch(:to)
            tag_frames = frame_range.map { |frame_index|
              frame_data = frames[frame_index]
              frame = frame_data.fetch(:frame)
              {
                path: path,
                w: frame[:w],
                h: frame[:h],
                tile_x: frame[:x],
                tile_y: frame[:y],
                tile_w: frame[:w],
                tile_h: frame[:h],
                flip_horizontally: false,
                duration: frame_data.fetch(:duration).idiv(50) * 3, # 50ms = 3 ticks
                metadata: {
                  slices: slice_bounds_for_frame(slices_data, frame_index, frame.slice(:w, :h))
                }
              }
            }
            apply_animation_direction! tag_frames, frame_tag_data.fetch(:direction)
            result[tag.to_sym] = Animations.build(frames: tag_frames)
          end
        }
      end

      # Reads an Aseprite Spritesheet JSON data file and returns a hash of sprites.
      #
      # If a tag has only one frame, the sprite will be returned directly, otherwise an
      # array of sprites will be returned.
      def read_as_sprites(json_path)
        animations = read_as_animations json_path
        animations.transform_values { |animation|
          sprites = animation[:frames].map { |frame|
            frame[:values].to_sprite(frame.slice(:duration, :metadata))
          }
          sprites.length == 1 ? sprites.first : sprites
        }
      end

      # Returns a new animation with all frames (and associated slices) flipped
      # horizontally.
      def flip_animation_horizontally(animation)
        {
          frames: animation[:frames].map { |frame|
            values = frame[:values]
            frame.merge(
              values: values.merge(flip_horizontally: !values[:flip_horizontally]),
              metadata: {
                slices: frame[:metadata][:slices].transform_values { |bounds|
                  bounds.merge(x: values[:w] - bounds[:x] - bounds[:w])
                }
              }
            )
          }
        }
      end

      private

      def sprite_path(sprite_sheet_data, json_path)
        last_slash_index = json_path.rindex '/'
        json_path[0..last_slash_index] + sprite_sheet_data.fetch(:meta).fetch(:image)
      end

      def slice_bounds_for_frame(slices_data, frame_index, frame_size)
        {}.tap { |slices|
          slices_data.each do |slice_data|
            name = slice_data.fetch(:name).to_sym
            key_frame = slice_data[:keys].select { |slice_key_data|
              slice_key_data.fetch(:frame) <= frame_index
            }.last
            slice_bounds = key_frame.fetch(:bounds).dup
            slice_bounds[:y] = frame_size[:h] - slice_bounds[:y] - slice_bounds[:h]
            slices[name] = slice_bounds
          end
        }
      end

      def apply_animation_direction!(frames, direction)
        case direction
        when 'pingpong'
          (frames.size - 2).downto(1) do |index|
            frames << frames[index]
          end
        end
      end

      def deep_symbolize_keys!(value)
        case value
        when Hash
          symbolize_keys!(value)
          value.each_value do |hash_value|
            deep_symbolize_keys!(hash_value)
          end
        when Array
          value.each do |array_value|
            deep_symbolize_keys!(array_value)
          end
        end

        value
      end

      def symbolize_keys!(hash)
        hash.each_key do |key|
          next unless key.is_a? String

          hash[key.to_sym] = hash.delete(key)
        end
        hash
      end
    end
  end
end

