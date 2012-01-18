Q = require "./quinto"
fs = require "fs"
path = require 'path'

maxPlayers = 10000
maxGames = 10000

objFromJsonWithProto = (proto, filename, e, f) ->
  fs.readFile(filename, (err, data) ->
    if err
      e(err)
    else
      t = ->
      t.prototype = proto.prototype
      obj = new t()
      for k, v of JSON.parse(data)
        obj[k] = v
      f(obj)
  )

blankObjWithProto = (proto) ->
  f = ->
  f.prototype = proto.prototype
  new f()

intSorter = (a, b) ->
  parseInt(a, 10) - parseInt(b, 10)

idsFromDir = (dir, e, f) ->
  fs.readdir(dir, (err, files) ->
    if err
      e(err)
    else
      f(files.sort(intSorter))
  )

normalizeEmail = (email) ->
  email.toLowerCase().replace("/", '').replace("\0", '')

Q.Player.load = (id, e, f) ->
  objFromJsonWithProto(Q.Player, "./tmp/players/#{id}/player", e, (player) ->
    delete player.hash
    f(player)
  )

Q.Player.lookup = (email, e, f) ->
  json_file = "./tmp/emails/#{normalizeEmail(email)}"
  path.exists(json_file, (exists) ->
    if exists
      objFromJsonWithProto(Q.Player, json_file, e, f)
    else
      f(null)
  )

Q.Player.prototype.tryPersist = (hash, i, e, f) ->
  if i > maxPlayers
    e('too many players in database')
  else
    json_id_file = "./tmp/players/#{i}/player"
    path.exists(json_id_file, (exists) =>
      if exists
        @tryPersist(hash, i+1, e, f)
      else
        @id = i
        fs.mkdir("./tmp/players/#{i}", 0755, (err) =>
          if err
            e(err)
          else
            fs.mkdir("./tmp/players/#{i}/games", 0755, (err) =>
              if err
                e(err)
              else
                obj = {id: i, name: @name, email: @email, token: @token, hash: hash}
                fs.writeFile(json_id_file, JSON.stringify(obj), (err) =>
                  if err
                    e(err)
                  else
                    fs.symlink("../players/#{i}/player", "./tmp/emails/#{normalizeEmail(@email)}", (err) =>
                      if err
                        e(err)
                      else
                        f()
                    )
                )
            )
        )
    )

Q.Player.prototype.persist = (hash, e, f) ->
  if @id
    f()
  else
    path.exists("./tmp/emails/#{normalizeEmail(@email)}", (exists) =>
      if exists
        e("email already exists in database: #{@email}")
      else
        @tryPersist(hash, 1, e, f)
    )

Q.Player.prototype._gameList = (ids, games, e, f) ->
  id = ids.pop()
  if id?
    Q.Game.load(id, e, (game) =>
      games.push({id: game.id, players: (p.email for p in game.players)})
      @_gameList(ids, games, e, f)
    )
  else
    f(games)

Q.Player.prototype.gameList = (e, f) ->
  idsFromDir("./tmp/players/#{@id}/games", e, (ids) =>
    @_gameList(ids, [], e, f)
  )

Q.Game.load = (id, e, f) ->
  game = blankObjWithProto(Q.Game)
  game.id = id
  game.loadPlayers(e, (players) =>
    game.players = players
    idsFromDir("./tmp/games/#{id}/states", e, (states) =>
      Q.GameState.load(id, states[states.length - 1], e, (state) =>
        state.game = game
        game.states = [state]
        f(game)
      )
    )
  )

Q.Game.prototype._loadPlayers = (ids, players, e, f) ->
  id = ids.shift()
  if id?
    objFromJsonWithProto(Q.Player, "./tmp/games/#{@id}/players/#{id}", e, (player) =>
      players.push(player)
      @_loadPlayers(ids, players, e, f)
    )
  else
    f(players)

Q.Game.prototype.loadPlayers = (e, f) ->
  idsFromDir("./tmp/games/#{@id}/players", e, (ids) =>
      @_loadPlayers(ids, [], e, f)
  )

Q.Game.prototype.persistPlayers = (players, i, e, f) ->
  p = players[i]
  if p?
    fs.writeFile("./tmp/players/#{p.id}/games/#{@id}", "", (err) =>
      if err
        e(err)
      else
        fs.symlink("../../../players/#{p.id}/player", "./tmp/games/#{@id}/players/#{i}", (err) =>
          if err
            e(err)
          else
            @persistPlayers(players, i+1, e, f)
        )
    )
  else
    f()

Q.Game.prototype.tryPersist = (i, e, f) ->
  if i > maxGames
    e('too many games in database')
  else
    path.exists("./tmp/games/#{i}", (exists) =>
      if exists
        @tryPersist(i+1, e, f)
      else
        @id = i
        fs.mkdir("./tmp/games/#{i}", 0755, (err) =>
          if err
            e(err)
          else
            fs.mkdir("./tmp/games/#{i}/players", 0755, (err) =>
              if err
                e(err)
              else
                fs.mkdir("./tmp/games/#{i}/states", 0755, (err) =>
                  if err
                    e(err)
                  else
                    @persistPlayers(@players, 0, e, f)
                )
            )
        )
    )

Q.Game.prototype.persist = (e, f) ->
  if @id
    f()
  else
    @tryPersist(1, e, f)

Q.GameState.load = (gameId, moveCount, e, f) =>
  objFromJsonWithProto(Q.GameState, "./tmp/games/#{gameId}/states/#{moveCount}", e, f)

Q.GameState.prototype.persist = (e, f) ->
  json_file = "./tmp/games/#{@game.id}/states/#{@moveCount}"
  path.exists(json_file, (exists) =>
    if exists
      f()
    else
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
      fs.writeFile(json_file, JSON.stringify(obj), (err) =>
        if err
          e(err)
        else
          f()
      )
  )

