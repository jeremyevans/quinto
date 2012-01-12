Q = require "./quinto"
fs = require "fs"
path = require 'path'

maxPlayers = 10000
maxGames = 10000

objFromJsonWithProto = (proto, filename) ->
  f = ->
  f.prototype = proto.prototype
  obj = new f()
  for k, v of JSON.parse(fs.readFileSync(filename))
    obj[k] = v
  obj

blankObjWithProto = (proto) ->
  f = ->
  f.prototype = proto.prototype
  new f()

intSorter = (a, b) ->
  parseInt(a, 10) - parseInt(b, 10)

idsFromDir = (dir) ->
  fs.readdirSync(dir).sort(intSorter)

normalizeEmail = (email) ->
  email.toLowerCase().replace("/", '').replace("\0", '')

Q.Player.load = (id) ->
  player = objFromJsonWithProto(Q.Player, "./tmp/players/#{id}/player")
  delete player.password
  player

Q.Player.lookup = (email) ->
  json_file = "./tmp/emails/#{normalizeEmail(email)}"
  if path.existsSync(json_file)
    player = objFromJsonWithProto(Q.Player, json_file)

Q.Player.prototype.persist = (password) ->
  unless @id
    json_email_file = "./tmp/emails/#{normalizeEmail(@email)}"
    if path.existsSync(json_email_file)
      throw "email already exists in database: #{@email}"
    for i in [1..maxPlayers]
      json_id_file = "./tmp/players/#{i}/player"
      unless path.existsSync(json_id_file)
        @id = i
        obj = {id: i, name: @name, email: @email, token: @token}
        fs.mkdirSync("./tmp/players/#{i}", 0755)
        fs.mkdirSync("./tmp/players/#{i}/games", 0755)
        fs.writeFileSync(json_id_file, JSON.stringify(obj))
        fs.symlinkSync("../players/#{i}/player", json_email_file)
        return

Q.Player.prototype.gameList = ->
  for i in idsFromDir("./tmp/players/#{@id}/games").reverse()
    game = Q.Game.load(i)
    {id: game.id, players: (p.email for p in game.players)}

Q.Game.load = (id) ->
  game = blankObjWithProto(Q.Game)
  game.id = id
  game.players = (objFromJsonWithProto(Q.Player, "./tmp/games/#{id}/players/#{i}") for i in idsFromDir("./tmp/games/#{id}/players"))
  states = idsFromDir("./tmp/games/#{id}/states")
  game.states = [Q.GameState.load(id, states[states.length - 1])]
  game.state().game = game
  game

Q.Game.prototype.persist = ->
  unless @id
    for i in [1..maxGames]
      unless path.existsSync("./tmp/games/#{i}")
        @id = i
        fs.mkdirSync("./tmp/games/#{i}", 0755)
        fs.mkdirSync("./tmp/games/#{i}/players", 0755)
        fs.mkdirSync("./tmp/games/#{i}/states", 0755)
        for p, j in @players
          fs.writeFileSync("./tmp/players/#{p.id}/games/#{i}", "")
          fs.symlinkSync("../../../players/#{p.id}/player", "./tmp/games/#{i}/players/#{j}")
        return

Q.GameState.load = (gameId, moveCount) ->
  objFromJsonWithProto(Q.GameState, "./tmp/games/#{gameId}/states/#{moveCount}")

Q.GameState.prototype.persist = ->
  json_file = "./tmp/games/#{@game.id}/states/#{@moveCount}"
  unless path.existsSync(json_file)
    fs.writeFileSync(json_file, JSON.stringify({
      gameId: @game.id
      moveCount: @moveCount
      toMove: @toMove
      tiles: @tiles
      board: @board
      lastMove: @lastMove
      passCount: @passCount
      gameOver: @gameOver
      racks: @racks
      scores: @scores
    }))

