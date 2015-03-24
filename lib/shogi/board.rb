require "shogi/csa/board"
require "shogi/usi/board"

module Shogi
  class Error               < StandardError; end
  class CodingError         < Error; end
  class FormatError         < Error; end
  class UndefinedPieceError < Error; end
  class MoveError           < Error; end
  class MovementError       < Error; end

  class Board
    include CSA::Board
    include USI::Board

    attr_accessor :default_format
    attr_accessor :validate_movement
    def initialize(default_format=:csa, position=nil)
      @default_format = default_format
      if position
        set_from_csa(position)
      else
        @position = default_position
        @captured = []
      end
      @validate_movement = true
    end

    def move(movement_lines, format=@default_format)
      movement_lines.each_line do |movement|
        movement.chomp!
        __send__("move_by_#{format.to_s}", movement)
      end
      self
    end

    def at(place)
      array_x = to_array_x_from_shogi_x(place[0].to_i)
      array_y = to_array_y_from_shogi_y(place[1].to_i)
      @position[array_y][array_x]
    end

    def show(format=@default_format)
      $stdout.puts __send__("to_#{format}")
    end

    private
    def default_position
      [["-KY", "-KE", "-GI", "-KI", "-OU", "-KI", "-GI", "-KE", "-KY"],
       [   "", "-HI",    "",    "",    "",    "",    "", "-KA",    ""],
       ["-FU", "-FU", "-FU", "-FU", "-FU", "-FU", "-FU", "-FU", "-FU"],
       [   "",    "",    "",    "",    "",    "",    "",    "",    ""],
       [   "",    "",    "",    "",    "",    "",    "",    "",    ""],
       [   "",    "",    "",    "",    "",    "",    "",    "",    ""],
       ["+FU", "+FU", "+FU", "+FU", "+FU", "+FU", "+FU", "+FU", "+FU"],
       [   "", "+KA",    "",    "",    "",    "",    "", "+HI",    ""],
       ["+KY", "+KE", "+GI", "+KI", "+OU", "+KI", "+GI", "+KE", "+KY"]]
    end

    def raise_movement_error(message)
      if @validate_movement
        raise MovementError, message
      end
    end

    def to_array_x_from_shogi_x(shogi_x)
      9 - shogi_x
    end

    def to_array_y_from_shogi_y(shogi_y)
      shogi_y - 1
    end

    def to_shogi_x_from_array_x(array_x)
      9 - array_x
    end

    def to_shogi_y_from_array_y(array_y)
      array_y + 1
    end
  end
end
