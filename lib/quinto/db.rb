begin
  require_relative '../../.env'
rescue LoadError
end

require_relative 'structs'
require 'sequel'
require 'json'
require 'bcrypt'
require 'securerandom'

module Quinto
  DB = Sequel.connect(ENV.delete('QUINTO_DATABASE_URL') || ENV.delete('DATABASE_URL'))
  DB.extension :date_arithmetic, :pg_array, :pg_row
  Sequel.extension :pg_array_ops
  DB.register_row_type(:game_states)

  require 'logger'
  #DB.loggers << Logger.new($stdout)
  DB.freeze

  ps_hash = lambda do |keys|
    h = {}
    keys.each do |k|
      h[k.to_sym] = :"$#{k}"
    end
    h
  end

  PlayerInsert = DB[:players].prepare(:insert, :player_insert, ps_hash.call(%w"email hash"))
  GameInsert = DB[:games].prepare(:insert, :games_insert, ps_hash.call(%w"player_ids"))
  GameStateInsert = DB[:game_states].prepare(:insert, :game_state_insert, ps_hash.call(%w"game_id move_count to_move tiles board last_move pass_count game_over racks scores"))
  DeleteFinishedGameStates = DB[:game_states].prepare(:delete, :game_states_delete, ps_hash.call(%w"game_id"))

  FinishedGameStates = DB[:games].
    where(:id=>:$id).
    select(:finished_game_states).
    prepare(:single_value, :finished_game_states)

  PlayerFromEmail = DB[:players].
    select(:id).
    where(:email=>:$email).
    prepare(:first, :player_from_email)

  PlayerGames = DB[:games].
    where(Sequel.pg_array_op(:player_ids).contains(Sequel.pg_array([:$player_id], :integer))).
    select{[:id, array_remove(:player_ids, :$player_id).as(:pids), (finished_game_states=~nil).as(:active)]}.
    reverse(:id).
    prepare([:map, [:id, :pids, :active]], :player_games)

  PlayerEmails = DB[:players].
    where(:id=>Sequel.pg_array_op(:$player_ids).any).
    select(:id, :email).
    prepare([:to_hash, :id, :email], :player_emails)

  GameFromIdPlayer = DB[:games].
    where(:id=>:$game_id).
    where(Sequel.pg_array_op(:player_ids).contains(Sequel.pg_array([:$player_id], :integer))).
    select(:player_ids).
    prepare(:single_value, :game_from_id_player)

  game_state_ds = DB[:game_states].
    select(:move_count, :to_move, :tiles, :board, :last_move, :pass_count, :game_over, :racks, :scores).
    where(:game_id=>:$game_id)

  CurrentGameState = game_state_ds.
    reverse(:move_count).
    prepare(:first, :current_game_state)

  GameStateAt = game_state_ds.
    where(:move_count=>:$move_count).
    prepare(:first, :game_state_at)

  PackFinishedGame = DB[:games].
    where(:id=>:$game_id).
    prepare(:update,
            :pack_finished_game_states,
            :finished_game_states=>DB[:game_states].
              where(:game_id=>:$game_id).
              select{array_agg(:game_states).order(:move_count)})

  TOKEN_LENGTH = 16

  class << Player
    def from_email(email)
      unless id = PlayerFromEmail.call(:email=>email)
        raise Error, "User not found"
      end

      new(id[:id], email)
    end
  end

  class << Game
    def start(players)
      start_with_tiles(players, DEFAULT_TILE_BAG.shuffle)
    end

    def start_with_tiles(players, tiles)
      num_players = players.length

      unless num_players >= 2
        raise Error, "must have at least 2 players"
      end

      DB.transaction do
        game = Game.new(GameInsert.call(:player_ids=>Sequel.pg_array(players.map(&:id))), players)
        GameState.empty(game, tiles, num_players).persist
      end
    end

    def from_id_player(game_id, player_id)
      player_ids = GameFromIdPlayer.call(:game_id=>game_id, :player_id=>player_id) || []
      player_email_map = PlayerEmails.call(:player_ids=>Sequel.pg_array(player_ids.uniq))
      new(game_id, player_ids.map{|pid| Player.new(pid, player_email_map[pid])})
    end
  end

  class Player
    def active_and_finished_games
      games = PlayerGames.call(:player_id=>id)
      player_ids = []
      games.each do |_, pids, _|
        player_ids.concat(pids)
      end
      player_email_map = PlayerEmails.call(:player_ids=>Sequel.pg_array(player_ids.uniq))

      active, finished = {}, {}
      games.each do |game_id, pids, act|
        (act ? active : finished)[game_id] = pids.map{|pid| player_email_map[pid]}.join(', ')
      end

      [active, finished]
    end

    def stats(other_player)
      other_id = other_player.id
      players = {}
      moves = {}
      final_moves = {}

      DB[:games].
        where(Sequel.pg_array_op(:player_ids).contains([id, other_id])).
        where(Sequel.pg_array_op(:player_ids).cardinality=>2).
        exclude(:finished_game_states=>nil).
        select_map([:id, :finished_game_states, :player_ids]).
        each do |id, fgs, fgp|
          players[id] = fgp
          moves[id] = fgs.map{|gs| gs.values_at(:to_move, :last_move)}
          final_moves[id] = fgs.find{|gs| gs[:game_over]}[:scores]
        end

      player_map = {true=>{id=>other_id, other_id=>id}, false=>{id=>id, other_id=>other_id}}
      player_tiles = {id=>[], other_id=>[]}
      players.each do |game_id, player_ids|
        player_ids.each_with_index do |player_id, i|
          moves[game_id].each do |other_player, move|
            if move && !move.empty?
              player_tiles[player_map[other_player == i][player_id]] << move
            end
          end
        end
      end

      player_numbers = {}
      player_tiles.each do |player_id, move_tiles|
        player_numbers[player_id] = move_tiles.map do |move_tile|
          move_tile.split.map{|x| x.to_i}
        end
      end

      number_counts = {id=>Hash.new(0), other_id=>Hash.new(0)}
      player_numbers.each do |player_id, moves|
        moves.flatten.each{|n| number_counts[player_id][n] += 1}
      end

      # Number of tiles per player
      player_numbers[id].flatten.length
      player_numbers[other_id].flatten.length

      # Number of moves per player
      num_moves = {id=>0, other_id=>0}
      players.each do |game_id, player_ids|
        player_ids.each_with_index do |player_id, i|
          moves[game_id].each do |other_player, move|
            if move
              num_moves[player_map[other_player == i][player_id]] += 1
            end
          end
        end
      end

      tiles_per_move = {}
      num_moves.each do |player_id, n|
        tiles_per_move[player_id] = player_numbers[player_id].flatten.length/n.to_f
      end

      number_percentages = {id=>{}, other_id=>{}}
      number_counts.each do |player_id, counts|
        counts.each do |tile, count|
          number_percentages[player_id][tile] = count.to_f/player_numbers[player_id].flatten.length
        end
      end

      wins = {id=>0, other_id=>0}
      scores = {id=>0, other_id=>0}
      players.each do |game_id, player_ids|
        player_ids.each_with_index do |player_id, i|
          next unless final_moves[game_id]
          final_scores = JSON.parse(final_moves[game_id])
          scores[player_id] += final_scores[i]
          wins[player_id] += 1 if final_scores.max == final_scores[i]
        end
      end

      {:games=>moves.length, :number_counts=>number_counts, :num_moves=>num_moves, :tiles_per_move=>tiles_per_move, :number_percentages=>number_percentages, :wins=>wins, :scores=>scores}
    end
  end

  class GameState
    def persist
      DB.transaction do
        GameStateInsert.call(:game_id=>game.id, :move_count=>move_count, :to_move=>to_move, :tiles=>tiles.to_json, :board=>board.to_json, :last_move=>last_move, :pass_count=>pass_count, :game_over=>game_over, :racks=>racks.to_json, :scores=>scores.to_json)

        if game_over
          PackFinishedGame.call(:game_id=>game.id)
          DeleteFinishedGameStates.call(:game_id=>game.id)
        end
      end

      self
    end

    def last_play
      return [] unless last_move
      last_move.split.map{|m| m.match(/\A\d+([a-z]\d+)\z/)[1]}
    end
  end

  class Game
    def state(move_count=nil)
      unless row = move_count ? GameStateAt.call(:game_id=>id, :move_count=>move_count) : CurrentGameState.call(:game_id=>id)
        if fgs = FinishedGameStates.call(:id=>id)
          row = if move_count
            fgs.find{|gs| gs[:move_count] == move_count}
          else
            fgs.last
          end
        end

        unless row
          raise Error, "No matching game state for game #{id}"
        end
      end

      GameState.new(self, row[:move_count], row[:to_move], JSON.parse(row[:tiles]), JSON.parse(row[:racks]), JSON.parse(row[:scores]), row[:pass_count], row[:game_over], JSON.parse(row[:board]), row[:last_move])
    end
  end
end
