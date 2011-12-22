express = require 'express'
cs = require 'coffee-script'
Q = require "./quinto"
fs = require "fs"

app = express.createServer()
app.client_js = cs.compile(fs.readFileSync('client.coffee', 'ascii'))
app.use express.static("#{__dirname}/public")
app.use express.bodyParser()
app.use express.cookieParser()
app.use express.session({secret: fs.readFileSync('session.secret')})

app.get '/app.js', (req, res) ->
  res.send(app.client_js, {'Content-Type': 'text/javascript'})

app.get '/game/view', (req, res) ->
  res.json([{action: 'drawBoard', board: app.game.state.board}])

app.get '/game/new', (req, res) ->
  app.game = (new Q.Game [new Q.Player('player1@foo.com'), new Q.Player('player2@bar.com')])
  res.json([{action: 'drawBoard', board: app.game.state.board}, {action: 'drawRack', rack: app.game.state.racks[0]}])

port = process.env.VMC_APP_PORT or 3000
app.listen port
console.log "Listening on #{port}..."

