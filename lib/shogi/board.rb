module Shogi
  class Board
    class Error               < StandardError; end
    class CodingError         < Error; end
    class FormatError         < Error; end
    class UndefinedPieceError < Error; end
    class MoveError           < Error; end
    class MovementError       < Error; end

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
      @count = 0
    end

    def to_csa
      csa_rows = ""

      @position.each_with_index do |row, i|
        csa_row = ""
        row.each do |cell|
          if cell == ""
            csa_row << " * "
          else
            csa_row << cell
          end
        end
        csa_rows << "P#{i + 1}#{csa_row}\n"
      end

      sente = "P+"
      gote = "P-"
      @captured.each do |piece|
        if piece[0] == "+"
          sente << "00#{piece[1..2]}"
        else
          gote << "00#{piece[1..2]}"
        end
      end
      csa_rows << "#{sente}\n"
      csa_rows << "#{gote}\n"

      csa_rows
    end

    def set_from_csa(csa)
      position = []
      cell_pattern = '[+-][A-Z]{2}| \* '
      csa_lines = csa.each_line.to_a
      csa_lines.slice(0, 9).to_enum.with_index do |row, i|
        position_row = []
        row.chomp!
        unless /\AP#{i + 1}(#{cell_pattern}){9}\z/ =~ row
          raise FormatError, "Format Error: line P#{i + 1}"
        end
        row[2..28].scan(/#{cell_pattern}/) do |cell|
          if cell == " * "
            position_row << ""
          else
            position_row << cell
          end
        end
        position << position_row
      end
      @position = position

      captured = []
      csa_lines.slice(9, 2).each do |captured_line|
        captured_line.chomp!
        unless /\AP[+-](00[A-Z]{2})*\z/ =~ captured_line
          raise FormatError, "Format Error: captured piece line"
        end
        turn = captured_line[1]
        captured_line[2..-1].scan(/00([A-Z]{2})/) do |cell|
          captured << turn + cell[0]
        end
      end
      @captured = captured
    end

    def to_usi
      @position.map {|row|
        usi_row = ""
        space_count = 0
        row.each do |cell|
          if cell == ""
            space_count += 1
          else
            if space_count > 0
              usi_row << space_count.to_s
              space_count = 0
            end
            usi = Piece.const_get(cell[1..2]).new.usi
            if cell[0] == "-"
              usi_row << usi.downcase
            else
              usi_row << usi
            end
          end
        end
        if space_count > 0
          usi_row << space_count.to_s
          space_count = 0
        end
        usi_row
      }.join("/") << "\n"
    end

    def move_from_csa(movement)
      $stderr.puts "warning: Shogi::Board#move_from_csa(movement) is deprecated. Use Shogi::Board#move(movement, :csa)"
      move(movement, :csa)
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

    def move_by_csa(csa)
      unless /\A[+-](00|[1-9]{2})[1-9]{2}[A-Z]{2}\z/ =~ csa
        raise FormatError, "Wrong CSA format: #{csa}"
      end

      unless Piece.const_defined?(csa[5..6])
        raise UndefinedPieceError, "Undefined piece: #{csa[5..6]}"
      end

      if csa[1..2] == "00"
        before_piece = csa[0] + csa[5..6]
        unless @captured.include?(before_piece)
          raise MoveError, "Not captured piece: #{before_piece}"
        end
        before_cell = before_piece
        before_piece = Piece.const_get(before_cell[1..2]).new
      else
        before_x = to_array_x_from_shogi_x(csa[1].to_i)
        before_y = to_array_y_from_shogi_y(csa[2].to_i)
        before_cell = @position[before_y][before_x]
        if before_cell == ""
          raise MoveError, "Before cell is blank"
        end
        before_piece = Piece.const_get(before_cell[1..2]).new

        unless csa[0] == before_cell[0]
          raise MoveError, "Not your piece: #{before_cell}"
        end
        unless csa[5..6] == before_cell[1..2]
          after_piece = Piece.const_get(csa[5..6]).new
          unless before_piece.promoter == after_piece.class
          raise MoveError, "Don't promote: #{before_cell[1..2]} -> #{csa[5..6]}"
          end

          after_y = to_array_y_from_shogi_y(csa[4].to_i)
          if csa[0] == "+"
            unless after_y < 3 || before_y < 3
              raise_movement_error("Don't promote this move: #{csa}")
            end
          else
            unless after_y > 6 || before_y > 6
              raise_movement_error("Don't promote this move: #{csa}")
            end
          end
        end
      end

      after_x = to_array_x_from_shogi_x(csa[3].to_i)
      after_y = to_array_y_from_shogi_y(csa[4].to_i)
      after_cell = @position[after_y][after_x]
      if csa[0] == after_cell[0]
        raise MoveError, "Your piece on after cell: #{csa}"
      end

      if csa[1..2] == "00"
        unless after_cell == ""
          raise MoveError, "Exist piece on after cell"
        end
      else
        if csa[0] == "+"
          movement_x = after_x - before_x
          movement_y = before_y - after_y
        else
          movement_x = before_x - after_x
          movement_y = after_y - before_y
        end

        unless before_piece.move?(movement_x, movement_y)
          raise_movement_error("Invalid movement: #{csa}")
        end
      end

      unless after_cell == ""
        after_piece = Piece.const_get(after_cell[1..2]).new
        if after_piece.class.const_defined?(:CHILD)
          @captured << "#{csa[0]}#{after_piece.class::CHILD}"
        else
          @captured << "#{csa[0]}#{after_cell[1..2]}"
        end
      end
      @position[after_y][after_x] = "#{csa[0]}#{csa[5..6]}"

      if csa[1..2] == "00"
        used = nil

        @captured.each_with_index do |captured_piece, i|
          if captured_piece == before_cell
            used = @captured.delete_at(i)
            break
          end
        end

        unless used == before_cell
          raise CodingError, "[Bug] missing piece in captured"
        end
      else
        @position[before_y][before_x] = ""
      end

      self
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

    # brainking
    def move_by_bki(bki)
      index = 0
      promoted = false

      if bki[index] == "+"
        promoted = true
        index += 1
      end

      koma = to_csa_koma_from_bki(bki[index])
      if promoted
        koma = promote(koma)
      end
      index += 1

      before_x = -1
      before_y = -1
      if /[1-9]/ =~ bki[index]
        before_x = bki[index].to_i
        index += 1
      elsif /[a-i]/ =~ bki[index]
        before_y = to_csa_y_from_bki(bki[index])
        index += 1
      end

      hand = false
      if bki[index] == "*"
        hand = true
      end
      index += 1

      after_x = bki[index].to_i
      index += 1

      after_y = to_csa_y_from_bki(bki[index])
      index += 1

      if hand
        move_by_csa(get_csa(is_black, 0, 0, after_x, after_y, koma))
        @count = @count + 1
        return self
      end

      @position.each_with_index do |row, y|
        if before_y > 0 && to_array_y_from_shogi_y(before_y) != y
          next
        end

        row.each_with_index do |cell, x|
          if before_x > 0 && to_array_x_from_shogi_x(before_x) != x
            next
          end

          if cell == attach_prefix_teban(is_black, koma)
            begin
              move_by_csa(get_csa(is_black, to_shogi_x_from_array_x(x), to_shogi_y_from_array_y(y), after_x, after_y, (bki[index] == "+" ? promote(koma) : koma)))
              @count = @count + 1
              return self
            rescue
              next
            end
          end
        end
      end
    end

    def is_black
      @count % 2 == 0
    end

    def attach_prefix_teban(black, str)
      (black ? "+" : "-") + str
    end

    def get_csa(black, before_x, before_y, after_x, after_y, koma)
      attach_prefix_teban(black, before_x.to_s + before_y.to_s + after_x.to_s + after_y.to_s + koma)
    end

    def to_csa_koma_from_bki(koma)
      hash = {
        "P" => "FU",
        "L" => "KY",
        "N" => "KE",
        "S" => "GI",
        "G" => "KI",
        "B" => "KA",
        "R" => "HI",
        "K" => "OU"
      }
      hash[koma]
    end

    def promote(koma)
      hash = {
        "FU" => "TO",
        "KY" => "NY",
        "KE" => "NK",
        "GI" => "NG",
        "KA" => "UM",
        "HI" => "RY"
      }
      hash[koma]
    end

    def to_csa_y_from_bki(y)
      y.ord - "a".ord + 1
    end
  end
end
