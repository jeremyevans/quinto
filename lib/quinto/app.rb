require 'roda'
require_relative 'game'
require_relative 'db'

module Quinto
  class App < Roda
    TEST_MODE = ENV['QUINTO_TEST'] == '1'

    plugin :static, %w'/app.js /index.html /jquery-ui.min.js /jquery.min.js /spinner.gif /style.css'
    plugin :json

    plugin :not_found do
      "Not Found"
    end

    plugin :error_handler do |e|
      puts e
      puts e.backtrace
      e.message
    end

    route do |r|
      r.root do
        r.redirect '/index.html'
      end

      r.on "player" do
        r.post "login" do
          set_player_json(Player.from_login(r['email'], r['password']))
        end

        r.post "register" do
          set_player_json(Player.register(r['email'], r['password']))
        end
      end

      r.on "game" do
        player = player_from_request

        r.post "new" do
          email_str = r['emails']

          if TEST_MODE
            email_str, tiles = email_str.split(':', 2)
            tiles = JSON.parse(tiles) if tiles
          end

          emails = email_str.split(',')
          total_players = emails.length + 1
          players = emails.map{|email| Player.from_email(email)}
          players.unshift(player)

          emails = players.map(&:email)
          unless emails.length == emails.uniq.length
            raise Error, "cannot have same player in two separate positions"
          end

          game_state = if tiles
            Game.start_with_tiles(players, tiles)
          else
            Game.start(players)
          end

          new_game_json(game_state, player)
        end

        r.get "list" do
          game_list_json(player)
        end

        r.get "join" do
          game_state = game_state_from_request
          new_game_json(game_state, player)
        end

        r.get "check", :move_count do |move_count|
          game_id = r["gameId"]
          if Game.still_at_move(game_id, move_count)
            [poll_json(move_count)]
          else
            game_state = game_state_from_request
            update_actions_json(game_state, player)
          end
        end

        r.post "pass" do
          move_or_pass(&:pass)
        end

        r.post "move" do
          move_or_pass{|game_state| game_state.move(r['move'])}
        end
      end
    end

    def set_player_json(player)
      [{"action"=>"setPlayer", "player"=>player.to_h}]
    end

    UPDATE_ACTIONS_KEYS = {:board=>:board, :scores=>:scores, :to_move=>:toMove, :pass_count=>:passCount, :move_count=>:moveCount}.freeze
    def update_actions_json(game_state, player)
      state = {}
      UPDATE_ACTIONS_KEYS.each{|k,v| state[v] = game_state[k]}
      state["rack"] = game_state.racks[game_state.game.player_position(player)]
      json = [{"action"=>"updateInfo", "state"=>state}]

      if game_state.game_over
        json << {"action"=>"gameOver", "winners"=>game_state.winners}
      elsif player.id != game_state.player_to_move.id
        json << poll_json(game_state.move_count)
      end
      
      json
    end

    def poll_json(move_count)
        {"action"=>"poll", "poll"=>"/game/check/#{move_count}"}
    end

    def new_game_json(game_state, player)
      [{"action"=>"newGame", "players"=>game_state.game.player_emails, "position"=>game_state.game.player_position(player), "gameId"=>game_state.game.id}] +
        update_actions_json(game_state, player)
    end

    def game_list_json(player)
      [{"action"=>"listGames", "games"=>player.active_games.map{|game_id, players| {"id"=>game_id, "players"=>players}}}]
    end

    def player_from_request
      Player.from_id_token(request["playerId"].to_i, request["playerToken"])
    end

    def game_state_from_request
      unless game = Game.from_id_player(request["gameId"].to_i, request["playerId"].to_i)
        raise Error, "invalid game for player"
      end
      
      game.state
    end

    def move_or_pass
      player = player_from_request
      game_state = game_state_from_request

      if game_state.game_over?
        raise Error, "Game already ended"
      end

      p [game_state.to_move, game_state.game.players]
      unless player.id == game_state.player_to_move.id
        raise Error, "Not your turn to move #{player.id} #{game_state.player_to_move.id}"
      end

      game_state = yield(game_state)
      game_state.persist

      update_actions_json(game_state, player)
    end
  end
end
