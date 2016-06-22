require_relative 'structs'
require 'sequel'
require 'json'
require 'bcrypt'
require 'securerandom'

module Quinto
  DB = Sequel.connect(ENV['QUINTO_DATABASE_URL'] || ENV['DATABASE_URL'])
  require 'logger'
  DB.loggers << Logger.new($stdout)

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
        :players__id=>:g__player_id).
      order(Sequel.desc(:g__game_id)).
      exclude(:players__id=>:$id).
      select_group(:g__game_id).
      select_append{string_agg(:players__email, Sequel.lit('? ORDER BY g.position', ', ')).as(:emails)}.
      prepare([:to_hash, :game_id, :emails], ps_name)
  end
  PlayerActiveGames = player_games.call(:exclude, :player_active_games)
  PlayerFinishedGames = player_games.call(:where, :player_finished_games)

  GameFromIdPlayer = DB[:players].
    join(:game_players, :players__id=>:game_players__player_id).
    select(:players__id, :players__email).
    where(:game_players__game_id=>:$game_id).
    where(:game_players__game_id=>DB[:game_players].
      select(:game_id).
      where(:player_id=>:$player_id)).
    order(:game_players__position).
    prepare(:all, :game_from_id_player)

  CurrentGameState = DB[:game_states].
    select(:move_count, :to_move, :tiles, :board, :last_move, :pass_count, :game_over, :racks, :scores).
    where(:game_id=>:$game_id).
    where(:move_count=>DB[:game_states].
      select{max(move_count)}.
      where(:game_id=>:$game_id)).
    prepare(:first, :current_game_state)

  GameStillAtMove = DB[:game_states].
    select{Sequel.as({max(:move_count)=>:$move_count}, :still_at_move)}.
    where(:game_id=>:$game_id).
    prepare(:first, :game_still_at_move)

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

    def still_at_move(game_id, move_count)
      GameStillAtMove.call(:game_id=>game_id, :move_count=>move_count)[:still_at_move]
    end
  end

  class Player
    def active_games
      PlayerActiveGames.call(:id=>id)
    end

    def finished_games
      PlayerFinishedGames.call(:id=>id)
    end
  end

  class GameState
    def persist
      GameStateInsert.call(:game_id=>game.id, :move_count=>move_count, :to_move=>to_move, :tiles=>tiles.to_json, :board=>board.to_json, :last_move=>last_move, :pass_count=>pass_count, :game_over=>game_over, :racks=>racks.to_json, :scores=>scores.to_json)
      self
    end
  end

  class Game
    def state
      unless row = CurrentGameState.call(:game_id=>id)
        raise Error, "No current game state for game #{id}"
      end

      GameState.new(self, row[:move_count], row[:to_move], JSON.parse(row[:tiles]), JSON.parse(row[:racks]), JSON.parse(row[:scores]), row[:pass_count], row[:game_over], JSON.parse(row[:board]), row[:last_move])
    end
  end
end
