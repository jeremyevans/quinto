require_relative 'structs'

module Quinto
  RACK_SIZE = 5
  MAX_RUN = 5
  SUM_EQUAL = 5
  BOARD_COLS = 17
  BOARD_ROWS = 17
  START_COL = 8
  START_ROW = 8

	DEFAULT_TILE_BAG = [1, 1, 1, 1, 1, 1,
		2, 2, 2, 2, 2, 2,
		3, 3, 3, 3, 3, 3, 3,
		4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
		5, 5, 5, 5, 5, 5,
		6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
		7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
		8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
		9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
		10, 10, 10, 10, 10, 10, 10].shuffle

  def self.position(x, y)
    "#{col(x)}#{y}"
  end

  def self.col(x)
    (97 + x).chr
  end

  class Game
    def initialize(id=nil, players=nil, state=nil)
      raise Error, "Game needs at least 2 players" unless players.length >= 2
      super
    end

    def player_emails
      players.map(&:email)
    end

    def player_position(player)
      players.each_with_index{|p,i| return i if p.id == player.id}
      raise Error, "Game#player_position called with player #{player.id} not in game #{players}"
    end

    def state
      self[:state] ||= GameState.empty(self, DEFAULT_TILE_BAG.shuffle, players.length)
    end

    def move(move_str)
      self.state = state.move(move_str)
    end

    def pass
      self.state = state.pass
    end
  end

  class GameState
    def initialize(*a)
      raise Error, "cannot create an empty GameState for a game" if a.empty?
      super
    end

    def self.empty(game, tiles, num_players)
      game_state = new(game, 0, 0, tiles, (1..num_players).map{[]}, [0] * num_players, 0, false, {}, nil)
      game_state.send(:fill_racks)
      game_state
    end

    def empty?
      board.empty?
    end

    def freeze
      super
      tiles.freeze
      racks.freeze.each(&:freeze)
      scores.freeze
      board.freeze
      self
    end

    def pass
      raise Error, "cannot pass if a game has finished" if game_over
      gs = dup
      gs.pass_count += 1
      gs.last_move = nil
      gs.moved
    end

    def move(move_str)
      raise Error, "cannot move if a game has finished" if game_over
      gs = dup
      gs.pass_count = 0
      gs.last_move = move_str
      move = parse_move(move_str)

      if move.empty? || move.length > RACK_SIZE
        raise Error, "Must play between 1 and #{RACK_SIZE} tiles"
      end

      move.each do |tile_place|
        gs.use_rack_tile(tile_place)
      end

      gs.check_move(move)
      gs.check_board
      gs.update_score(move)
      gs.fill_racks
      gs.moved
    end

    def winners
      max = scores.max
      scores.map.with_index do |score, i|
        game.players[i].email if score == max
      end.compact
    end

    def player_to_move
      game.players[to_move]
    end

    def game_over?
      pass_count == racks.length || racks.any?(&:empty?)
    end

    protected

    def reorder_tiles(adj_move, move)
      return adj_move if move.empty?

      not_adjacent = []
      change = false

      while tile_place = move.shift
        if tile_place.board_adjacent?(self)
          adj_move.unshift(tile_place)
          change = true
        elsif tile_place.adjacent?(adj_move)
          adj_move << tile_place
          change = true
        else
          not_adjacent << tile_place
        end
      end

      if change
        reorder_tiles(adj_move, not_adjacent)
      end

      adj_move.concat(not_adjacent)
    end

    def check_move(move)
      move.each(&:check)
      move = if board.empty?
        reorder_tiles(move[0...1], move[1..-1])
      else
        reorder_tiles([], move.dup)
      end
      
      is_empty = board.empty?
      row = col = nil

      move.each_with_index do |tile_place, i|
        pos = tile_place.position

        case i
        when 0
          row = tile_place.row
          col = tile_place.col
        when 1
          if row == tile_place.row
            col = -1
          elsif col = tile_place.col
            row = -1
          else
            raise Error, "attempt to place tile not in same row or column: row: #{row} col #{Quinto.col(col)} pos: #{pos}"
          end
        else
          if col >= 0
            if col != tile_place.col
              raise Error, "attempt to place tile not in same column: col #{Quinto.col(col)} pos: #{pos}"
            end
          elsif row != tile_place.row
            raise Error, "attempt to place tile not in same row : row #{row} pos: #{pos}"
          end
        end

        unless tile_place.board_adjacent?(self)
          raise Error, "attempt to place tile not adjacent to existing tile: pos: #{pos}" unless is_empty && i == 0
        end

        if board[pos]
          raise Error, "attempt to place tile over existing tile: pos: #{pos}"
        end
        
        board[pos] = tile_place.tile
      end
      
      if is_empty
        unless board[Quinto.position(START_COL, START_ROW)]
          raise Error, "opening move must have tile placed in starting square #{Quinto.position(START_COL, START_ROW)}"
        end

        if move.length == 1 && (move.first.tile % SUM_EQUAL) != 0
          raise Error, "single tile opening move must be a multiple of #{SUM_EQUAL}"
        end
      end

      nil
    end

    def moved
      self.move_count += 1
      self.to_move = move_count % racks.length
      if self.game_over = game_over?
        subtract_unplayed_tiles
      end
      freeze
    end

    def use_rack_tile(tile_place)
      rack = racks[to_move]
      pos = nil
      rack.each_with_index do |tile, i|
        if tile == tile_place.tile
          pos = i
          break
        end
        nil
      end

      unless pos
        raise Error, "Tile #{tile_place.tile} not in rack"
      end

      rack.delete_at(pos)
      nil
    end

    def tile_score(col, row)
      board[Quinto.position(col, row)]
    end
    alias have_tile? tile_score

    def have_any_tile?(*positions)
      positions.any?{|col, row| have_tile?(col, row)}
    end

    def check_board
      BOARD_ROWS.times do |row|
        col = 0
        while col < BOARD_COLS
          length = 1

          if run_total = board[Quinto.position(col, row)]
            (1..MAX_RUN).each do |i|
              break unless tile = board[Quinto.position(col+i, row)]
              run_total += tile
              length += 1
            end

            if length > MAX_RUN
              raise Error, "more than #{MAX_RUN} consecutive tiles in row #{row} columns #{Quinto.col(col)}-#{Quinto.col(col+length-1)}"
            end

            if length > 1 && (run_total % SUM_EQUAL) != 0
              raise Error, "consecutive tiles do not sum to multiple of #{SUM_EQUAL} in row #{row} columns #{Quinto.col(col)}-#{Quinto.col(col+length-1)} sum #{run_total}"
            end
          end

          col += length
        end
      end

      BOARD_COLS.times do |col|
        row = 0
        while row < BOARD_ROWS
          length = 1

          if run_total = board[Quinto.position(col, row)]
            (1..MAX_RUN).each do |i|
              break unless tile = board[Quinto.position(col, row+i)]
              run_total += tile
              length += 1
            end

            if length > MAX_RUN
              raise Error, "more than #{MAX_RUN} consecutive tiles in column #{Quinto.col(col)} rows #{row}-#{row+length-1}"
            end

            if length > 1 && (run_total % SUM_EQUAL) != 0
              raise Error, "consecutive tiles do not sum to multiple of #{SUM_EQUAL} in column #{Quinto.col(col)} rows #{row}-#{row+length-1} sum #{run_total}"
            end
          end

          row += length
        end
      end

      nil
    end

    def update_score(move)
      sum = 0
      if board.length == move.length
        sum += move.map(&:tile).inject(0, :+)
      else
        col_runs = {}
        row_runs = {}

        move.each do |tile_position|
          row = tile_position.row
          col = tile_position.col

          if !row_runs[row] && tile_position.col_adjacent?(self)
            run_sum = 0
				    row_runs[row] = true
            min_col = max_col = col
            min_col -= 1 while have_tile?(min_col, row)
            max_col += 1 while have_tile?(max_col, row)
            ((min_col+1)..(max_col-1)).each do |c|
               run_sum += tile_score(c, row)
            end
            sum += run_sum
          end

          col = tile_position.col
          if !col_runs[col] && tile_position.row_adjacent?(self)
            run_sum = 0
				    col_runs[col] = true
            min_row = max_row = row
            min_row -= 1 while have_tile?(col, min_row)
            max_row += 1 while have_tile?(col, max_row)
            ((min_row+1)..(max_row-1)).each do |r|
               run_sum += tile_score(col, r)
            end
            sum += run_sum
          end
        end
      end

      scores[to_move] += sum
    end

    def parse_move(move_str)
      move_str.split(' ').map do |tile_str|
        unless match = tile_str.match(/\A(\d\d?)([a-z])(\d\d?)\z/)
          raise Error, "Invalid move tile #{tile_str}"
        end
        tile = match[1].to_i
        col = match[2].ord - 97
        row = match[3].to_i
        TilePlace.new(tile, col, row)
      end
    end

    def subtract_unplayed_tiles
      racks.each_with_index do |rack, i|
        scores[i] -= rack.inject(0, :+)
      end
    end

    def fill_racks
      racks.each do |rack|
        if (num_tiles = RACK_SIZE - rack.length) > 0
          rack.concat(take_tiles(num_tiles)).sort!
        end
      end
    end

    def take_tiles(num)
      num = tiles.length if num > tiles.length
      tiles.shift(num)
    end

    private

    def initialize_copy(other)
      super
      self.tiles = other.tiles.dup
      self.racks = other.racks.map(&:dup)
      self.scores = other.scores.dup
      self.board = other.board.dup
    end
  end


  class TilePlace
    def check
      if col < 0 || row < 0 || col > BOARD_COLS || row > BOARD_ROWS
        raise Error, "attempt to place tile outside of board: pos: #{position}"
      end
    end

    def tile_position
      "#{tile}#{position}"
    end

    def position
      Quinto.position(col, row)
    end

    def adjacent?(move)
      move.any? do |tile_place|
        if row == tile_place.row
          col == tile_place.col - 1 || col == tile_place.col + 1
        elsif col == tile_place.col
          row == tile_place.row - 1 || row == tile_place.row + 1
        end
      end
    end

    def board_adjacent?(game_board)
      game_board.send(:have_any_tile?, [col+1, row], [col-1, row], [col, row+1], [col, row-1])
    end

    def col_adjacent?(game_board)
      game_board.send(:have_any_tile?, [col+1, row], [col-1, row])
    end

    def row_adjacent?(game_board)
      game_board.send(:have_any_tile?, [col, row+1], [col, row-1])
    end
  end
end 
