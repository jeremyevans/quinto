Q = require "./quinto"
Future = require './future_wrapper'
pg = require('pg').native

F = {}
F.connect = Future.wrap_wait(((args...) -> pg.connect(args...)), 1)
F.query = Future.wrap_wait(((args...) ->
  console.log(args[0...args.length-1]) if process.env.QUINTO_ECHO
  F.connect(process.env.DATABASE_URL.replace(/^postgres/, 'tcp')).query(args...)
), 1)

insert_value  = (v) ->
  if v instanceof Array
    "{#{(insert_value(v1) for v1 in v).join(',')}}"
  else
    v

insert = (table, values) ->
  ks = []
  ps = []
  vs = []
  i = 0
  for own k, v of values
    ks.push(k)
    vs.push(insert_value(v))
    ps.push "$#{++i}"

  F.query({text: "INSERT INTO #{table}(#{ks.join(', ')}) VALUES (#{ps.join(', ')}) RETURNING *", values: vs}).rows[0]

select = (table, where) ->
  ws = []
  vs = []
  i = 0
  for own k, v of where
    ws.push "#{k} = $#{++i}"
    vs.push v
  F.query({text: "SELECT * FROM #{table} WHERE #{ws.join(' AND ')}", values: vs})

first = (table, values) ->
  select(table, values).rows[0]

normalizeEmail = (email) ->
  email.toLowerCase().replace("/", '').replace("\0", '')

objFromRow = (proto, row) ->
  f = ->
  f.prototype = proto.prototype
  obj = new f()
  for own k, v of row
    obj[k] = v
  obj

Q.Player.load = (id) ->
  if player = first('players', {id: id})
    delete player.hash
    objFromRow(Q.Player, player)

Q.Player.lookup = (email) ->
  if player = first('players', {email: normalizeEmail(email)})
    objFromRow(Q.Player, player)

Q.Player.prototype.persist = (hash) ->
  @id = insert('players', {email: normalizeEmail(@email), token: @token, hash: hash}).id

Q.Player.prototype.gameList = ->
  sql = '''
       SELECT g.game_id AS id, players.email 
       FROM players
       JOIN (
         SELECT *
         FROM game_players
         WHERE game_id IN (SELECT game_id FROM game_players WHERE player_id = $1)
           AND game_id NOT IN (SELECT game_id FROM game_states WHERE game_over = TRUE)
       ) AS g ON (players.id = g.player_id)
       ORDER BY g.game_id DESC, g.position
        '''
  games = {}
  game_ids = []
  for row in F.query({text: sql, name: 'gameList', values: [@id]}).rows
    id = "#{row.id}"
    unless players = games[id]
      game_ids.push(id)
      players = games[id] = []
    players.push(row.email)
  {id: 0+i, players: games[i]} for i in game_ids

Q.Game.load = (id) ->
  game = objFromRow(Q.Game, first('games', {id: id}))
  game.init({})
  sql = '''
        SELECT players.id, players.email, players.token
        FROM players
        JOIN game_players ON (players.id = game_players.player_id)
        WHERE game_players.game_id = $1
        ORDER BY game_players.position
        '''
  game.players = for row in F.query({text: sql, name: 'gameLoad', values: [id]}).rows
    objFromRow(Q.Player, row)
  game.states = [Q.GameState.load(id, "(SELECT max(move_count) AS m FROM game_states WHERE game_id = $1)")]
  game.state().game = game
  game

Q.Game.gameChanged = (gameId, moveCount) ->
  F.query({text: "(SELECT max(move_count) AS m FROM game_states WHERE game_id = $1)", name: 'gameChanged', values: [gameId]}).rows[0].m > moveCount

Q.Game.prototype.persist = ->
  @id = F.query({text: "INSERT INTO games DEFAULT VALUES RETURNING *", name: 'insertGame'}).rows[0].id
  for p, i in @players
    insert('game_players', {game_id: @id, player_id: p.id, position: i})

Q.GameState.load = (gameId, moveCount) =>
  vals = [gameId]
  unless typeof(moveCount) == 'string'
    vals.push(moveCount)
    moveCount = '$2'

  sql = """
        SELECT game_id AS "gameId"
             , move_count AS "moveCount"
             , to_move AS "toMove"
             , tiles
             , board
             , racks
             , scores
             , last_move AS "lastMove"
             , pass_count AS "passCount"
             , game_over AS "gameOver"
        FROM game_states
        WHERE game_id = $1 and move_count = #{moveCount}
        """
  state = objFromRow(Q.GameState, F.query({text: sql, name: (if vals.length == 1 then 'lastStateLoad' else 'stateLoad'), values: vals}).rows[0])
  state.board = JSON.parse(state.board)
  state.racks = JSON.parse(state.racks)
  state.scores = JSON.parse(state.scores)
  state.tiles = JSON.parse(state.tiles)
  state

Q.GameState.prototype.persist = ->
  obj = {
    game_id: @game.id
    move_count: @moveCount
    to_move: @toMove
    tiles: JSON.stringify(@tiles)
    scores: JSON.stringify(@scores)
    racks: JSON.stringify(@racks)
    board: JSON.stringify(@board)
    last_move: @lastMove
    pass_count: @passCount
    game_over: @gameOver
  }
  insert('game_states', obj)
