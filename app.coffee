express = require 'express'
cs = require 'coffee-script'
Q = require "./quinto"
fs = require "fs"
crypto = require 'crypto'
querystring = require 'querystring'
require './persist_json'
bcrypt = require 'bcrypt'

app = express.createServer()
app.client_js = -> cs.compile(fs.readFileSync('client.coffee', 'ascii') + fs.readFileSync('quinto.coffee', 'ascii'))
app.use express.logger()
app.use express.static("#{__dirname}/public")
app.use express.bodyParser()
app.use express.cookieParser()
app.use express.session({secret: fs.readFileSync('session.secret', 'ascii')})

parseInt10 = (v) -> parseInt(v, 10)

loadPlayer = (req) ->
  player = Q.Player.load(parseInt10(req.param('playerId')))
  unless player.token == req.param('playerToken')
    throw "Invalid player token"
  player

loadGame = (req) ->
  Q.Game.load(parseInt10(req.param('gameId')))

updateActions = (gs, player)->
  actions = [{
    action: 'updateInfo'
    state: {
      board: gs.board
      rack: gs.racks[playerPosition(gs.game, player)]
      players: (p.name for p in gs.game.players)
      scores: gs.scores
      toMove: gs.toMove
      passCount: gs.passCount
      moveCount: gs.moveCount
    }
    poll: "/game/check/#{gs.moveCount}"
  }]
  if gs.gameOver
    actions.unshift({action: "gameOver", winners: (p.name for p in gs.winners())})
  actions

playerPosition = (game, player) ->
  for p, i in game.players
    return i if p.id == player.id

newGame = (game, player, res) ->
  pos = playerPosition(game, player)
  actions = updateActions(game.state(), player)
  actions.unshift({action: 'newGame', players: (p.name for p in game.players), position: pos, gameId: game.id})
  res.json(actions)

app.get '/app.js', (req, res) ->
  res.send(app.client_js(), {'Content-Type': 'text/javascript'})

app.get '/game/check/:moveCount', (req, res) ->
  gs = loadGame(req).state()
  if gs.moveCount == parseInt10(req.param('moveCount'))
    res.json([{action: 'poll', poll: "/game/check/#{gs.moveCount}"}])
  else
    res.json(updateActions(gs, loadPlayer(req)))

moveOrPass = (f) ->
  (req, res) ->
    player = loadPlayer(req)
    game = loadGame(req)
    gs = game.state()
    if player.id == game.players[gs.toMove].id
      f(gs, req)
      gs = game.state()
      gs.persist()
      res.json(updateActions(gs, player))
    else
      throw new Error('Not your turn')

app.post '/player/register', (req, res) ->
  token = querystring.escape(crypto.randomBytes(16))
  player = new Q.Player(req.param('name'), req.param('email'), token)
  player.persist(bcrypt.encrypt_sync(req.param('password'), bcrypt.gen_salt_sync(10)))
  res.json([action: 'setPlayer', player: player])

app.post '/player/login', (req, res) ->
  player = Q.Player.lookup(req.param('email'))
  unless player or !bcrypt.compare_sync(req.param('password'), player.password)
    throw "User not found or passwords don't match"
  delete player.password
  res.json([action: 'setPlayer', player: player])

app.post '/game/new', (req, res) ->
  starter = loadPlayer(req)
  players = for email in req.param('emails').split(new RegExp(' *, *'))
    player = Q.Player.lookup(email)
    unless player
      throw "No registered player with email: #{email}"
    delete player.password
    player
  players.unshift(starter)
  game = new Q.Game(players)
  game.persist()
  game.state().persist()
  newGame(game, starter, res)
  
app.get '/game/list', (req, res) ->
  player = loadPlayer(req)
  res.json([action: 'listGames', games: player.gameList()])

app.get '/game/join', (req, res) ->
  newGame(loadGame(req), loadPlayer(req), res)

app.post '/game/move', moveOrPass((gs, req) -> gs.game.move(req.param('move')))
app.post '/game/pass', moveOrPass((gs, req) -> gs.game.pass())

port = process.env.QUINTO_PORT or 3000
app.listen port
console.log "Listening on #{port}..."

