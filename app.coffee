express = require 'express'
cs = require 'coffee-script'
Q = require "./quinto"
fs = require "fs"
Future = require './future_wrapper'
crypto = require 'crypto'
require './persist_json'
bcrypt = require 'bcrypt'
TEST_MODE = process.env.QUINTO_TEST == '1'

app = express.createServer()
app.use express.logger()
app.use express.static("#{__dirname}/public")
app.use express.bodyParser()
app.use(express.errorHandler({ showStack: true, dumpExceptions: true}))

client_js = cs.compile(fs.readFileSync('client.coffee', 'ascii') + fs.readFileSync('quinto.coffee', 'ascii'))

randomBytes = Future.wrap_wait(crypto.randomBytes, 1)
genSalt = Future.wrap_wait(bcrypt.genSalt)
bcryptHash = Future.wrap_wait(bcrypt.hash)
bcryptCompare = Future.wrap_wait(bcrypt.compare)

fiberWrapper = (f, req, res, next) ->
  Fiber(->
    try
      f(req, res)
    catch err
      next(new Error(err))
  ).run()
get = (path, f) ->
  app.get path, (req, res, next) ->
    fiberWrapper(f, req, res, next)
post = (path, f) ->
  app.post path, (req, res, next) ->
    fiberWrapper(f, req, res, next)

enext = (next) ->
  (err) ->
    next(new Error(err))

#app.error((err, req, res) ->
#  res.send(err, 500)
#)

parseInt10 = (v) -> parseInt(v, 10)

pollAction = (gs) ->
  {action: 'poll', poll: "/game/check/#{gs.moveCount}"}

updateActions = (gs, player)->
  pos = playerPosition(gs.game, player)
  actions = [{
    action: 'updateInfo'
    state: {
      board: gs.board
      rack: gs.racks[pos]
      players: (p.name for p in gs.game.players)
      scores: gs.scores
      toMove: gs.toMove
      passCount: gs.passCount
      moveCount: gs.moveCount
    }
  }]
  if gs.gameOver
    actions.unshift({action: "gameOver", winners: (p.name for p in gs.winners())})
  else if pos != gs.toMove and !TEST_MODE
    actions.push(pollAction(gs))
  actions

playerPosition = (game, player) ->
  for p, i in game.players
    return i if p.id == player.id

newGame = (game, player, res) ->
  pos = playerPosition(game, player)
  actions = updateActions(game.state(), player)
  actions.unshift({action: 'newGame', players: (p.name for p in game.players), position: pos, gameId: game.id})
  res.json(actions)

loadPlayer = (req) ->
  player = Q.Player.load(parseInt10(req.param('playerId')))
  if player && player.token == req.param('playerToken')
    player
  else
    throw "Invalid player token"

loadGame = (req) ->
  Q.Game.load(parseInt10(req.param('gameId')))

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
      throw "Not your turn, current player is in position #{gs.toMove}, you are in position #{playerPosition(game, player)}"

lookupPlayers = (emails) ->
  for e in emails
    Q.Player.lookup(e) || (throw "No registered player with email: #{email}")

app.get '/app.js', (req, res, next) ->
  res.send(client_js, {'Content-Type': 'text/javascript'})

get '/game/check/:moveCount', (req, res) ->
  game = loadGame(req)
  gs = game.state()
  if gs.moveCount == parseInt10(req.param('moveCount'))
    res.json([pollAction(gs)])
  else
    res.json(updateActions(gs, loadPlayer(req)))

post '/player/register', (req, res) ->
  token = randomBytes(16).toString('base64')
  player = new Q.Player(req.param('name'), req.param('email'), token)
  hash = bcryptHash(req.param('password'), genSalt(10))
  player.persist(hash)
  res.json([action: 'setPlayer', player: player])

post '/player/login', (req, res) ->
  player = Q.Player.lookup(req.param('email'))
  if player && bcryptCompare(req.param('password'), player.hash)
    delete player.hash
    res.json([action: 'setPlayer', player: player])
  else
    throw "User not found or password doesn't match"

post '/game/new', (req, res) ->
  starter = loadPlayer(req)
  emails = if TEST_MODE
    ems = req.param('emails').split(':', 2)
    tiles = JSON.parse(ems[1])
    ems[0]
  else
    req.param('emails')

  players = lookupPlayers(emails.split(new RegExp(' *, *')))
  players.unshift(starter)
  game = if TEST_MODE and tiles?
    new Q.Game(players, {tiles: tiles})
  else
    new Q.Game(players)
  game.persist()
  game.state().persist()
  newGame(game, starter, res)
  
get '/game/list', (req, res) ->
  res.json([action: 'listGames', games: loadPlayer(req).gameList()])

get '/game/join', (req, res) ->
  newGame(loadGame(req), loadPlayer(req), res)

post '/game/move', moveOrPass((gs, req) -> gs.game.move(req.param('move')))
post '/game/pass', moveOrPass((gs, req) -> gs.game.pass())

port = process.env.QUINTO_PORT or 3000
app.listen port
console.log "Listening on #{port}..."

