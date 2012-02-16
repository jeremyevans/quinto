Q = require "./quinto"
Future = require './future_wrapper'
fs = require "fs"
path = require 'path'
ROOT = process.env.QUINTO_JSON_ROOT or './tmp'

maxPlayers = 10000
maxGames = 10000

F = {}
wrappedFuncs = [[fs, 'readFile'], [fs, 'readdir'], [fs, 'mkdir'], [fs, 'writeFile'], [fs, 'symlink'], [fs, 'unlink'], [fs, 'readlink']]
for [m, f] in wrappedFuncs
  F[f] = Future.wrap_wait(m[f])

F.exists = Future.wrap_wait(((p, f) -> path.exists(p, (e) -> f(null, e))))

objFromJsonWithProto = (proto, filename) ->
  data = F.readFile(filename)
  t = ->
  t.prototype = proto.prototype
  obj = new t()
  for k, v of JSON.parse(data)
    obj[k] = v
  obj

blankObjWithProto = (proto) ->
  f = ->
  f.prototype = proto.prototype
  new f()

intSorter = (a, b) ->
  parseInt(a, 10) - parseInt(b, 10)

idsFromDir = (dir) ->
  F.readdir(dir).sort(intSorter)

normalizeEmail = (email) ->
  email.toLowerCase().replace("/", '').replace("\0", '')

Q.Player.load = (id) ->
  player = objFromJsonWithProto(Q.Player, "#{ROOT}/players/#{id}/player")
  delete player.hash
  player

Q.Player.lookup = (email) ->
  json_file = "#{ROOT}/emails/#{normalizeEmail(email)}"
  if F.exists(json_file)
    objFromJsonWithProto(Q.Player, json_file)

Q.Player.tryNextId = 1
Q.Player.nextId = ->
  for i in [@tryNextId..maxPlayers] by 1
    try
      F.mkdir "#{ROOT}/players/#{i}", 0755
      @tryNextId = i+1
      return i
    catch err
      null
  throw 'too many players in database'

Q.Player.prototype.persist = (hash) ->
  return if @id
  if F.exists("#{ROOT}/emails/#{normalizeEmail(@email)}")
    throw "email already exists in database: #{@email}"
  @id = Q.Player.nextId()
  F.mkdir "#{ROOT}/players/#{@id}/games", 0755
  obj = {id: @id, email: @email, token: @token, hash: hash}
  F.writeFile "#{ROOT}/players/#{@id}/player", JSON.stringify(obj)
  F.symlink "../players/#{@id}/player", "#{ROOT}/emails/#{normalizeEmail(@email)}"

Q.Player.prototype.gameList = ->
  for i in idsFromDir("#{ROOT}/players/#{@id}/games").reverse()
    game = Q.Game.load(i)
    {id: game.id, players: (p.email for p in game.players)}

Q.Game.load = (id) ->
  game = blankObjWithProto(Q.Game)
  game.init({})
  game.id = id
  game.players = game.loadPlayers()
  states = idsFromDir("#{ROOT}/games/#{id}/states")
  state = Q.GameState.load id, states[states.length - 1]
  state.game = game
  game.states = [state]
  game

Q.Game.gameChanged = (gameId, moveCount) ->
  F.exists("#{ROOT}/games/#{gameId}/states/#{moveCount+1}")

Q.Game.prototype.loadPlayers = ->
  for i in idsFromDir("#{ROOT}/games/#{@id}/players")
    objFromJsonWithProto(Q.Player, "#{ROOT}/games/#{@id}/players/#{i}")

Q.Game.tryNextId = 1
Q.Game.nextId = ->
  for i in [@tryNextId..maxPlayers] by 1
    try
      F.mkdir "#{ROOT}/games/#{i}", 0755
      @tryNextId = i+1
      return i
    catch err
      null
  throw 'too many games in database'

Q.Game.prototype.persist = ->
  return if @id
  @id = Q.Game.nextId()
  F.mkdir "#{ROOT}/games/#{@id}/players", 0755
  F.mkdir "#{ROOT}/games/#{@id}/states", 0755
  for p, i in @players
    F.writeFile "#{ROOT}/players/#{p.id}/games/#{@id}", ""
    F.symlink "../../../players/#{p.id}/player", "#{ROOT}/games/#{@id}/players/#{i}"

Q.GameState.load = (gameId, moveCount) =>
  objFromJsonWithProto(Q.GameState, "#{ROOT}/games/#{gameId}/states/#{moveCount}")

Q.GameState.prototype.persist = ->
  json_file = "#{ROOT}/games/#{@game.id}/states/#{@moveCount}"
  unless F.exists(json_file)
    obj = {
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
    }
    F.writeFile(json_file, JSON.stringify(obj))
    if @gameOver
      for i in idsFromDir("#{ROOT}/games/#{@game.id}/players")
        playerId = path.basename(path.dirname(F.readlink("#{ROOT}/games/#{@game.id}/players/#{i}")))
        F.unlink("#{ROOT}/players/#{playerId}/games/#{@game.id}")
