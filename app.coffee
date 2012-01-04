express = require 'express'
cs = require 'coffee-script'
Q = require "./quinto"
fs = require "fs"

app = express.createServer()
app.client_js = -> cs.compile(fs.readFileSync('client.coffee', 'ascii') + fs.readFileSync('quinto.coffee', 'ascii'))
app.use express.logger()
app.use express.static("#{__dirname}/public")
app.use express.bodyParser()
app.use express.cookieParser()
app.use express.session({secret: fs.readFileSync('session.secret', 'ascii')})

app.game = (new Q.Game [new Q.Player('player1@foo.com'), new Q.Player('player2@bar.com')])
app.gameState = (req) -> app.game.state()

app.get '/app.js', (req, res) ->
  res.send(app.client_js(), {'Content-Type': 'text/javascript'})

parseInt10 = (v) -> parseInt(v, 10)
pI = (req) -> parseInt(req.param('playerId'), 10)

boardJson = (gs, playerId)->
  json = {
    action: 'updateInfo'
    state: {
      board: gs.board
      rack: gs.racks[playerId]
      players: (p.email for p in gs.game.players)
      scores: gs.scores
      toMove: gs.toMove
      passCount: gs.passCount
      moveCount: gs.moveCount
      playerId: playerId
    }
    poll: "/game/check/#{playerId}/#{gs.moveCount}"
  }
  if gs.gameOver
    json.state.gameOver = true
    json.state.winners = (winner.email for winner in gs.winners)
  json

app.get '/game/check/:playerId/:moveCount', (req, res) ->
  gs = app.gameState(req)
  i = pI(req)
  mc = parseInt10(req.param('moveCount'))
  if gs.moveCount == mc
    res.json([{action: 'poll', poll: "/game/check/#{i}/#{mc}"}])
  else
    res.json([boardJson(gs, i)])

moveOrPass = (f) ->
  (req, res) ->
    gs = app.gameState(req)
    i = pI(req)
    if i == gs.toMove
      f(gs, req)
      gs = gs.game.state()
      res.json([boardJson(gs, i)])
    else
      throw new Error('Not your turn')


app.post '/game/move/:playerId', moveOrPass((gs, req) -> gs.game.move(req.param('move')))
app.post '/game/pass/:playerId', moveOrPass((gs, req) -> gs.game.pass())

app.get '/game/join/:playerId', (req, res) ->
  gs = app.gameState(req)
  bj = boardJson(gs, pI(req))
  res.json([
    {action: 'newGame', players: bj.state.players}
    bj
  ])

port = process.env.VMC_APP_PORT or 3000
app.listen port
console.log "Listening on #{port}..."

