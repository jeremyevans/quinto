express = require 'express'
cs = require 'coffee-script'
Q = require "./quinto"
fs = require "fs"
crypto = require 'crypto'
querystring = require 'querystring'
require './persist_json'
bcrypt = require 'bcrypt'

app = express.createServer()
app.use express.logger()
app.use express.static("#{__dirname}/public")
app.use express.bodyParser()
app.use(express.errorHandler({ showStack: true, dumpExceptions: true}))

client_js = cs.compile(fs.readFileSync('client.coffee', 'ascii') + fs.readFileSync('quinto.coffee', 'ascii'))

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
  else if pos != gs.toMove
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

loadPlayer = (req, e, f) ->
  Q.Player.load(parseInt10(req.param('playerId')), e, (player) ->
    if player.token == req.param('playerToken')
      f(player)
    else
      console.log(player.token)
      console.log(req.param('playerToken'))
      e("Invalid player token")
  )

loadGame = (req, e, f) ->
  Q.Game.load(parseInt10(req.param('gameId')), e, f)

moveOrPass = (f) ->
  (req, res, next) ->
    e = enext(next)
    loadPlayer(req, e, (player) ->
      loadGame(req, e, (game) ->
        gs = game.state()
        if player.id == game.players[gs.toMove].id
          f(gs, req)
          gs = game.state()
          gs.persist(e, ->
            res.json(updateActions(gs, player))
          )
        else
          e("Not your turn, current player is in position #{gs.toMove}, you are in position #{playerPosition(game, player)}")
      )
    )

lookupPlayers = (emails, players, e, f) ->
  email = emails.shift()
  if email?
    Q.Player.lookup(email, e, (player) ->
      if player
        delete player.hash
        players.push(player)
        lookupPlayers(emails, players, e, f)
      else
        e("No registered player with email: #{email}")
    )
  else
    f(players)

app.get '/app.js', (req, res, next) ->
  res.send(client_js, {'Content-Type': 'text/javascript'})

app.get '/game/check/:moveCount', (req, res, next) ->
  e = enext(next)
  loadGame(req, e, (game) ->
    gs = game.state()
    if gs.moveCount == parseInt10(req.param('moveCount'))
      res.json([pollAction(gs)])
    else
      loadPlayer(req, e, (player) ->
        res.json(updateActions(gs, player))
      )
  )

app.post '/player/register', (req, res, next) ->
  e = enext(next)
  crypto.randomBytes(16, (err, buf) ->
    if err
      e(err)
    else
      token = querystring.escape(buf)
      player = new Q.Player(req.param('name'), req.param('email'), token)
      bcrypt.genSalt(10, (err, salt) ->
        if err
          e(err)
        else
          bcrypt.hash(req.param('password'), salt, (err, hash) ->
            if err
              e(err)
            else
              player.persist(hash, e, ->
                res.json([action: 'setPlayer', player: player])
              )
          )
      )
  )

app.post '/player/login', (req, res, next) ->
  e = enext(next)
  Q.Player.lookup(req.param('email'), e, (player) ->
    if player
      bcrypt.compare(req.param('password'), player.hash, (err, matches) ->
        if err
          e(err)
        else if matches
          delete player.hash
          res.json([action: 'setPlayer', player: player])
        else
          e("User not found or password doesn't match")
      )
    else
      e("User not found or password doesn't match")
  )

app.post '/game/new', (req, res, next) ->
  e = enext(next)
  loadPlayer(req, e, (starter) ->
    lookupPlayers(req.param('emails').split(new RegExp(' *, *')), [], e, (players) ->
      players.unshift(starter)
      game = new Q.Game(players)
      game.persist(e, ->
        game.state().persist(e, ->
          newGame(game, starter, res)
        )
      )
    )
  )
  
app.get '/game/list', (req, res, next) ->
  e = enext(next)
  loadPlayer(req, e, (player) ->
    player.gameList(e, (games) ->
      res.json([action: 'listGames', games: games])
    )
  )

app.get '/game/join', (req, res, next) ->
  e = enext(next)
  loadPlayer(req, e, (player) ->
    loadGame(req, e, (game) ->
      newGame(game, player, res)
    )
  )

app.post '/game/move', moveOrPass((gs, req) -> gs.game.move(req.param('move')))
app.post '/game/pass', moveOrPass((gs, req) -> gs.game.pass())

port = process.env.QUINTO_PORT or 3000
app.listen port
console.log "Listening on #{port}..."

