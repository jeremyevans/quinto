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
  self = @
  if i > maxPlayers
    e('too many players in database')
  else
    json_id_file = "./tmp/players/#{i}/player"
    path.exists(json_id_file, (exists) ->
      if exists
        self.tryPersist(hash, i+1, e, f)
      else
        self.id = i
        fs.mkdir("./tmp/players/#{i}", 0755, (err) ->
          if err
            e(err)
          else
            fs.mkdir("./tmp/players/#{i}/games", 0755, (err) ->
              if err
                e(err)
              else
                obj = {id: i, name: self.name, email: self.email, token: self.token, hash: hash}
                fs.writeFile(json_id_file, JSON.stringify(obj), (err) ->
                  if err
                    e(err)
                  else
                    fs.symlink("../players/#{i}/player", "./tmp/emails/#{normalizeEmail(self.email)}", (err) ->
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
  self = @
  if self.id
    f()
  else
    path.exists("./tmp/emails/#{normalizeEmail(self.email)}", (exists) ->
      if exists
        e("email already exists in database: #{self.email}")
      else
        self.tryPersist(hash, 1, e, f)
    )

Q.Player.prototype._gameList = (ids, games, e, f) ->
  self = @
  id = ids.pop()
  if id?
    Q.Game.load(id, e, (game) ->
      games.push({id: game.id, players: (p.email for p in game.players)})
      self._gameList(ids, games, e, f)
    )
  else
    f(games)

Q.Player.prototype.gameList = (e, f) ->
  self = @
  idsFromDir("./tmp/players/#{self.id}/games", e, (ids) ->
    self._gameList(ids, [], e, f)
  )

Q.Game.load = (id, e, f) ->
  self = @
  game = blankObjWithProto(Q.Game)
  game.id = id
  game.loadPlayers(e, (players) ->
    game.players = players
    idsFromDir("./tmp/games/#{id}/states", e, (states) ->
      Q.GameState.load(id, states[states.length - 1], e, (state) ->
        state.game = game
        game.states = [state]
        f(game)
      )
    )
  )

Q.Game.prototype._loadPlayers = (ids, players, e, f) ->
  self = @
  id = ids.shift()
  if id?
    objFromJsonWithProto(Q.Player, "./tmp/games/#{self.id}/players/#{id}", e, (player) ->
      players.push(player)
      self._loadPlayers(ids, players, e, f)
    )
  else
    f(players)

Q.Game.prototype.loadPlayers = (e, f) ->
  self = @
  idsFromDir("./tmp/games/#{self.id}/players", e, (ids) ->
      self._loadPlayers(ids, [], e, f)
  )

Q.Game.prototype.persistPlayers = (players, i, e, f) ->
  self = @
  p = players[i]
  if p?
    fs.writeFile("./tmp/players/#{p.id}/games/#{self.id}", "", (err) ->
      if err
        e(err)
      else
        fs.symlink("../../../players/#{p.id}/player", "./tmp/games/#{self.id}/players/#{i}", (err) ->
          if err
            e(err)
          else
            self.persistPlayers(players, i+1, e, f)
        )
    )
  else
    f()

Q.Game.prototype.tryPersist = (i, e, f) ->
  self = @
  if i > maxGames
    e('too many games in database')
  else
    path.exists("./tmp/games/#{i}", (exists) ->
      if exists
        self.tryPersist(i+1, e, f)
      else
        self.id = i
        fs.mkdir("./tmp/games/#{i}", 0755, (err) ->
          if err
            e(err)
          else
            fs.mkdir("./tmp/games/#{i}/players", 0755, (err) ->
              if err
                e(err)
              else
                fs.mkdir("./tmp/games/#{i}/states", 0755, (err) ->
                  if err
                    e(err)
                  else
                    self.persistPlayers(self.players, 0, e, f)
                )
            )
        )
    )

Q.Game.prototype.persist = (e, f) ->
  self = @
  if self.id
    f()
  else
    self.tryPersist(1, e, f)

Q.GameState.load = (gameId, moveCount, e, f) ->
  objFromJsonWithProto(Q.GameState, "./tmp/games/#{gameId}/states/#{moveCount}", e, f)

Q.GameState.prototype.persist = (e, f) ->
  self = @
  json_file = "./tmp/games/#{self.game.id}/states/#{self.moveCount}"
  path.exists(json_file, (exists) ->
    if exists
      f()
    else
      obj = {
        gameId: self.game.id
        moveCount: self.moveCount
        toMove: self.toMove
        tiles: self.tiles
        board: self.board
        lastMove: self.lastMove
        passCount: self.passCount
        gameOver: self.gameOver
        racks: self.racks
        scores: self.scores
      }
      fs.writeFile(json_file, JSON.stringify(obj), (err) ->
        if err
          e(err)
        else
          f()
      )
  )

