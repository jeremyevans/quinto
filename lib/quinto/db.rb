require_relative 'structs'
require 'sequel'
require 'json'
require 'bcrypt'
require 'securerandom'

module Quinto
  DB = Sequel.connect(ENV['QUINTO_DATABASE_URL'] || ENV['DATABASE_URL'])
  DB.extension :date_arithmetic
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
  GameInsert = DB[:games].prepare(:insert, :games_insert, {})
  GamePlayerInsert = DB[:game_players].prepare(:insert, :game_player_insert, ps_hash.call(%w"game_id player_id position"))
  GameStateInsert = DB[:game_states].prepare(:insert, :game_state_insert, ps_hash.call(%w"game_id move_count to_move tiles board last_move pass_count game_over racks scores"))

  PlayerFromEmail = DB[:players].
    select(:id).
    where(:email=>:$email).
    prepare(:first, :player_from_email)

  player_games = lambda do |meth, ps_name|
    DB[:players].
      join(DB[:game_players].
        where(:game_id=>DB[:game_players].
          select(:game_id).
          where(:player_id=>:$id).
          send(meth, :game_id=>DB[:game_states].
            select(:game_id).
            where(:game_over=>true))).
        as(:g),
        Sequel[:players][:id]=>Sequel[:g][:player_id]).
      order(Sequel.desc(Sequel[:g][:game_id])).
      exclude(Sequel[:players][:id]=>:$id).
      select_group(Sequel[:g][:game_id]).
      select_append{string_agg(Sequel[:players][:email], ', ').order(Sequel[:g][:position]).as(:emails)}.
      prepare([:to_hash, :game_id, :emails], ps_name)
  end
  PlayerActiveGames = player_games.call(:exclude, :player_active_games)
  PlayerFinishedGames = player_games.call(:where, :player_finished_games)

  GameFromIdPlayer = DB[:players].
    join(:game_players, Sequel[:players][:id]=>Sequel[:game_players][:player_id]).
    select(Sequel[:players][:id], Sequel[:players][:email]).
    where(Sequel[:game_players][:game_id]=>:$game_id).
    where(Sequel[:game_players][:game_id]=>DB[:game_players].
      select(:game_id).
      where(:player_id=>:$player_id)).
    order(Sequel[:game_players][:position]).
    prepare(:all, :game_from_id_player)

  game_state_ds = DB[:game_states].
    select(:move_count, :to_move, :tiles, :board, :last_move, :pass_count, :game_over, :racks, :scores).
    where(:game_id=>:$game_id)

  CurrentGameState = game_state_ds.
    reverse(:move_count).
    prepare(:first, :current_game_state)

  GameStateAt = game_state_ds.
    where(:move_count=>:$move_count).
    prepare(:first, :game_state_at)

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
        game = Game.new(GameInsert.call, players)
        players.each_with_index{|player, i| GamePlayerInsert.call(:game_id=>game.id, :player_id=>player.id, :position=>i)}
        GameState.empty(game, tiles, num_players).persist
      end
    end

    def from_id_player(game_id, player_id)
      new(game_id, GameFromIdPlayer.call(:game_id=>game_id, :player_id=>player_id).map{|row| Player.new(row[:id], row[:email])})
    end
  end

  class Player
    def active_games
      PlayerActiveGames.call(:id=>id)
    end

    def finished_games
      PlayerFinishedGames.call(:id=>id)
    end

    def stats(other_player)
      other_id = other_player.id
      game_ids = DB[:games].
        where(:id=>DB[:game_players].where(:player_id=>id).select(:game_id)).
        where(:id=>DB[:game_players].where(:player_id=>other_id).select(:game_id)).
        where(:id=>DB[:game_players].select_group(:game_id).having{{count.function.* => 2}}).
        where(:id=>DB[:game_states].where(:game_over).select(:game_id)).
        select_map(:id)

      players = DB[:game_players].order(:position).where(:game_id=>game_ids).to_hash_groups(:game_id, :player_id)
      moves = DB[:game_states].where(:game_id=>game_ids).to_hash_groups(:game_id, [:to_move, :last_move])
      final_moves = DB[:game_states].where(:game_id=>game_ids).where(:game_over).to_hash(:game_id, :scores)

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

      {:games=>game_ids.length, :number_counts=>number_counts, :num_moves=>num_moves, :tiles_per_move=>tiles_per_move, :number_percentages=>number_percentages, :wins=>wins, :scores=>scores}
    end
  end

  class GameState
    def persist
      GameStateInsert.call(:game_id=>game.id, :move_count=>move_count, :to_move=>to_move, :tiles=>tiles.to_json, :board=>board.to_json, :last_move=>last_move, :pass_count=>pass_count, :game_over=>game_over, :racks=>racks.to_json, :scores=>scores.to_json)
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
        raise Error, "No matching game state for game #{id}"
      end

      GameState.new(self, row[:move_count], row[:to_move], JSON.parse(row[:tiles]), JSON.parse(row[:racks]), JSON.parse(row[:scores]), row[:pass_count], row[:game_over], JSON.parse(row[:board]), row[:last_move])
    end
  end
end
