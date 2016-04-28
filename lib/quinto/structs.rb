module Quinto
  Error = Class.new(StandardError)

  Player = Struct.new(:id, :email, :token)
  Game = Struct.new(:id, :players, :state)
  GameState = Struct.new(:game, :move_count, :to_move, :tiles, :racks, :scores, :pass_count, :game_over, :board, :last_move)
  TilePlace = Struct.new(:tile, :col, :row)
end
