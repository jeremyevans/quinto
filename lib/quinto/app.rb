# frozen_string_literal: true
require_relative 'game'
require_relative 'db'

require 'roda'
require 'tilt/erubi'
require 'message_bus'
require 'strscan' # Needed for Rack::Multipart::Parser

module Quinto
  class App < Roda
    opts[:root] = File.expand_path('../../..', __FILE__)
    opts[:check_dynamic_arity] = false
    opts[:check_arity] = :warn

    TEST_MODE = ENV['QUINTO_TEST'] == '1'
    MESSAGE_BUS = MessageBus::Instance.new
    MESSAGE_BUS.configure(:backend=>:memory)

    plugin :direct_call
    plugin :public, :gzip=>true
    plugin :render, :escape=>true, :template_opts=>{:chain_appends=>true}
    plugin :symbol_views
    plugin :json
    plugin :param_matchers
    plugin :message_bus, :message_bus=>MESSAGE_BUS
    plugin :request_aref, :raise
    plugin :disallow_file_uploads
    plugin :Integer_matcher_max
    plugin :typecast_params_sized_integers, :sizes=>[64], :default_size=>64

    plugin :assets,
      :css=>%w'style.css',
      :js=>%w'message-bus.js message-bus-ajax.js app.js',
      :css_dir=>nil,
      :js_dir=>nil,
      :compiled_js_dir=>nil,
      :compiled_css_dir=>nil,
      :compiled_path=>nil,
      :precompiled=>File.expand_path('../../../compiled_assets.json', __FILE__),
      :prefix=>nil,
      :gzip=>true

    logger = case ENV['RACK_ENV']
    when 'development'
      Class.new{def write(_) end}.new
    else
      $stderr
    end
    plugin :common_logger, logger

    plugin :not_found do
      view(:content=>"<h1>Not Found</h1>")
    end

    plugin :error_handler do |e|
      case e
      when Roda::RodaPlugins::TypecastParams::Error
        response.status = 400
        view(:content=>"<h1>Invalid parameter submitted: #{h e.param_name}</h1>")
      else
        $stderr.puts "#{e.class}: #{e.message}", e.backtrace
        e.message
      end
    end

    plugin :rodauth, :csrf=>:route_csrf do
      enable :login, :logout, :create_account, :change_password, :change_login, :remember
      db DB
      prefix "/auth"
      accounts_table :players
      account_password_hash_column :hash
      require_email_address_logins? false
      update_session do
        super()
        session['email'] = account[:email]
      end
      after_change_login{session['email'] = DB[:players].where(:id=>session_value).get(:email)}
      logout_redirect '/auth/login'
      login_input_type 'text'

      after_login{remember_login}
      after_create_account{remember_login}
      remember_cookie_options :httponly=>true, :path=>'/'
      extend_remember_deadline? true
      remember_period :days=>365
    end

    plugin :content_security_policy do |csp|
      csp.default_src :none
      csp.style_src :self
      csp.form_action :self
      if TEST_MODE
        csp.script_src :self, :unsafe_eval
      else
        csp.script_src :self
      end
      csp.connect_src :self
      csp.base_uri :none
      csp.frame_ancestors :none
    end

    plugin :sessions,
      :secret=>ENV.delete('QUINTO_SESSION_SECRET'),
      :key => 'quinto.session'

    route do |r|
      r.public
      r.assets
      rodauth.load_memory

      r.on "auth" do
        r.rodauth
      end

      if player_id = rodauth.session_value
        @player = Player.new(player_id, session['email'])
      end

      r.root do
        if rodauth.logged_in?
          active, finished = player.active_and_finished_games
          @active_games = active.map{|id, players| ["#{id} - #{players}", id]}
          @finished_games = finished.map{|id, players| ["#{id} - #{players}", id]}
          :home
        else
          :index
        end
      end

      next unless player

      r.get "stats", :param => 'login' do |email|
        @other_player = Player.from_email(email.to_s)
        @stats = player.stats(@other_player)
        :stats
      end

      r.on "game" do
        r.is :param => 'id' do |game_id|
          r.redirect "/game/#{game_id.to_i}"
        end

        r.post "new" do
          check_csrf!
          email_str = typecast_params.str!('emails')

          if TEST_MODE
            email_str, tiles = email_str.split(':', 2)
            tiles = JSON.parse(tiles) if tiles
          end

          emails = email_str.split(',')
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

          r.redirect("/game/#{game_state.game.id}")
        end

        r.on Integer do |game_id|
          r.message_bus

          r.get do
            r.is do
              game_state = game_state_from_request(game_id)
              @players = game_state.game.player_emails
              @position = game_state.game.player_position(player)
              @game_id = game_state.game.id
              :board
            end

            r.is "check" do
              game_state = game_state_from_request(game_id)
              update_actions_json(game_state)
            end

            r.is "state", Integer do |move_count|
              game_state = game_state_from_request(game_id, move_count)
              update_actions_json(game_state, :previous=>true)
            end
          end

          r.post do
            check_csrf!

            r.is "pass" do
              move_or_pass(game_id, &:pass)
            end

            r.is "move" do
              move_or_pass(game_id){|game_state| game_state.move(typecast_params.str!('move'))}
            end
          end
        end
      end
    end

    attr_reader :player

    UPDATE_ACTIONS_KEYS = {:board=>:board, :scores=>:scores, :to_move=>:toMove, :pass_count=>:passCount, :move_count=>:moveCount, :game_over=>:gameOver}.freeze
    def update_actions_json(game_state, opts={})
      state = {}
      UPDATE_ACTIONS_KEYS.each{|k,v| state[v] = game_state[k]}
      state["rack"] = game_state.racks[game_state.game.player_position(player)]
      json = [{"action"=>"updateInfo", "state"=>state, "lastPlay"=>game_state.last_play}]

      if game_state.game_over
        json << {"action"=>"gameOver", "winners"=>game_state.winners}
      elsif player.id != game_state.player_to_move.id
        json << poll_json(game_state.move_count)
      end

      if opts[:previous]
        json << {"action"=>"previousState"}
      else
        json << {"action"=>"activeState"}
      end
      
      json
    end

    def poll_json(move_count)
      {"action"=>"poll"}
    end

    def game_state_from_request(game_id, move_count=nil)
      unless game = Game.from_id_player(game_id, player.id)
        raise Error, "invalid game for player"
      end
      
      game.state(move_count)
    end

    def move_or_pass(game_id)
      game_state = game_state_from_request(game_id)

      if game_state.game_over?
        raise Error, "Game already ended"
      end

      unless player.id == game_state.player_to_move.id
        raise Error, "Not your turn to move #{player.id} #{game_state.player_to_move.id}"
      end

      game_state = yield(game_state)
      game_state.persist

      MESSAGE_BUS.publish("/game/#{game_id}", 'null')
      update_actions_json(game_state)
    end
  end
end
