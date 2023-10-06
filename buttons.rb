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

# Contains methods for handling common button input logic.
module Buttons
  class << self
    # Processes mouse input for the given button (a hash with x, y, w, and h keys)
    # and updates the button hash with the following keys:
    #
    # [:hovered] +true+ while the mouse is inside the button
    #
    # [:hovered_ticks] the number of ticks the mouse has been inside the button
    #
    # [:clicked] +true+ if the mouse was clicked inside the button
    #
    # [:pressed] +true+ while the mouse is inside the button and the left mouse
    #            button is pressed
    #
    # [:pressed_ticks] the number of ticks the mouse has been inside the button
    #                  and the left mouse button is pressed
    #
    # [:released] +true+ during the tick when left mouse button was released after
    #             being pressed inside the button
    #
    # [:ticks_since_released] the number of ticks since the mouse was released
    def handle_mouse_input(mouse, button)
      button[:hovered_ticks] ||= 0
      button[:pressed_ticks] ||= 0
      button[:ticks_since_released] ||= 0
      button[:hovered] = mouse.inside_rect? button
      button[:hovered_ticks] = button[:hovered] ? button[:hovered_ticks] + 1 : 0
      button[:clicked] = button[:hovered] && mouse.click
      button[:pressed] = button[:hovered] && mouse.button_left
      button[:released] = button[:pressed_ticks].positive? && !mouse.button_left
      button[:pressed_ticks] = button[:pressed] ? button[:pressed_ticks] + 1 : 0
      button[:ticks_since_released] = button[:released] ? 0 : button[:ticks_since_released] + 1
    end
  end
end

