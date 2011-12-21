class Player
  constructor: (@email) ->

class GameState
  # Number of tiles each player has at one time
  @rackSize: 5

  # Maximum number of tiles in a row
  @maxLength = 5

  # What the sum of all consecutive tiles in a row or column must equal
  # a multiple of
  @sumEqual = 5

  # Dimensions of board
  @boardX: 17
  @boardY: 17

  # Default amount of each numbered tiles 
  # 6 #1s, 6 #2s, 7 #3s, etc.
  @tileCounts: [0, 6, 6, 7, 10, 6, 10, 14, 12, 12, 7]

  # Default tile bag used for games
  @tiles: (=>
    t = []
    for amount, tile in @tileCounts
      for j in [0...amount]
        t.push(tile)
    t)()

  # Empty board with no tiles played yet
  @emptyBoard: (null for x in [0...@boardX] for y in [0...@boardY])

  # Create an empty Quinto game
  @empty: (game) =>
    racks = ([] for p in game.players)
    scores = (0 for p in game.players)
    new @(null, {
      game: game,
      tiles: @tiles.slice().sort(-> 0.5 - Math.random()),
      board: @emptyBoard,
      empty: true,
      toMove: -1,
      racks: racks,
      scores:scores
    })

  # Create a new GameState based on the previous GameState with the given changes
  constructor: (@previous, changes) ->
    for own k, v of changes
      @[k] = v
    for own k, v of previous
      unless v instanceof Function
        @[k] ?= v

    if @gameOver
      throw("Game already ended, can't make more moves")

    @toMove = (@toMove + 1) % @racks.length
    @tiles = @tiles.slice()
    @racks = (@fillRack(rack).sort(@rackSort) for rack in @racks)

    for x in @racks
      if x.length == 0
        @gameOver = true

    @winners = @determineWinners() if @gameOver

  # Sort function for rack tiles
  rackSort: (a, b) -> parseInt(a, 10) - parseInt(b, 10)

  # Fill the rack so that it has rackSize number of tiles
  fillRack: (rack) =>
    rack.concat(@takeTiles(GameState.rackSize - rack.length))

  # Remove i number of tiles from the tile bag
  takeTiles: (i) =>
    @tiles.splice(0, if i >= @tiles.length then @tiles.length else i)

  # Make a move on the board, returning the new GameState
  move: (moves) =>
    b = (xs.slice() for xs in @board)
    racks = @racks.slice()
    racks[@toMove] = racks[@toMove].slice()
    rack = racks[@toMove]
    ts = @translateMoves(moves)
    for [n, x, y] in ts
      @useRackTile(rack, n)
    @checkValidMoves(b, ts)
    @checkBoard(b)
    runs = @getRuns(b, ts)
    scores = @scores.slice()
    scores[@toMove] += @sum(v for k, v of runs)
    changes = {board: b, racks: racks, scores: scores, lastMove: moves, lastRuns: runs}
    changes.empty = false if @empty
    new GameState(@, changes)

  # Pass making a move on the board, returning the new GameState
  pass: => new GameState(@, {lastMove: null, lastRuns: null})

  determineWinners: =>
    max = 0
    for s in @scores
      max = s if s > max
    @game.players[i] for s, i in @scores when s == max

  getRuns: (b, ts) ->
    scores = {}
    if @empty && ts.length == 1
      scores[@translatePos(ts[0][1], ts[0][2])] = ts[0][0]
    else
      for [n, x, y] in ts
        @xRun(scores, b, y, x) if b[y][x+1] or b[y][x-1]
        @yRun(scores, b, y, x) if (y > 0 and b[y-1][x]) or (y < GameState.boardY - 1 and b[y+1][x])
    scores

  xRun: (scores, b, y, x) ->
    xMin = x
    xMax = x
    xMin-- while b[y][xMin-1]
    xMax++ while b[y][xMax+1]
    scores["#{y}#{@translateCol(xMin)}-#{@translateCol(xMax)}"] ?= @sum(b[y][i] for i in [xMin..xMax])

  yRun: (scores, b, y, x) ->
    yMin = y
    yMax = y
    yMin-- while b[yMin-1] and b[yMin-1][x]
    yMax++ while b[yMax+1] and b[yMax+1][x]
    scores["#{@translateCol(x)}#{yMin}-#{yMax}"] ?= @sum(b[i][x] for i in [yMin..yMax])

  sum: (a) ->
    score = 0
    for x in a
      score += x
    score

  translateMoves: (moves) ->
    d = /\d/
    for m in moves.split(' ')
      x = if d.test(m[1]) then 2 else 1
      [
        parseInt(m[0...x], 10)
        m.charCodeAt(x) - 97
        parseInt(m[(x+1)..m.length], 10)
      ]

  translatePos: (x, y) ->
    "#{@translateCol(x)}#{y}"

  translateCol: (x) ->
    String.fromCharCode(x+97)

  checkValidMoves: (b, ts) =>
    mx = GameState.boardX
    my = GameState.boardY
    for [n, x, y] in ts
      if x >= mx or y >= my or x < 0 or y < 0
        throw("attempt to place tile outside of board: pos: #{@translatePos(x, y)}")

    ts = if @empty
      @reorderTiles(b, [ts[0]], ts[1..ts.length-1])
    else
      @reorderTiles(b, [], ts[0..ts.length-1])

    row = null
    col = null
    i = 0
    for [n, x, y] in ts
      switch i
        when 0
          row = x
          col = y
        when 1
          if row == x
            col = null
          else if col == y
            row = null
          else
            throw("attempt to place tile not in same row or column: row: #{row}, col: #{@translateCol(col)}, pos: #{@translatePos(x, y)}")
        else
          if row == null
            if col != y
              throw("attempt to place tile not in same column: col: #{@translateCol(col)}, pos: #{@translatePos(x, y)}")
          else if row != x
            throw("attempt to place tile not in same row: row: #{row}, pos: #{@translatePos(x, y)}")
      unless @empty && i == 0
        unless b[y][x-1] or (y > 0 and b[y-1][x]) or b[y][x+1] or (y < my - 1 and b[y+1][x])
          throw("attempt to place tile not adjacent to existing tile: pos: #{@translatePos(x, y)}")
      if b[y][x]
        throw("attempt to place tile over existing tile: pos: #{@translatePos(x, y)} tile: #{n}, existing: #{b[y][x]}")
      else
        b[y][x] = n
      i += 1
    if @empty
      unless b[8][8]
        throw("opening move must have tile placed in center square (i8)")
      unless @sum(n for [n, x, y] in ts) % GameState.sumEqual == 0 
        throw("opening move must sum to multiple of #{GameState.sumEqual}")

  reorderTiles: (b, adj_ts, ts) ->
    return adj_ts if ts.length == 0
    nadj_ts = []
    change = false
    for [n, x, y] in ts
      if b[y][x-1] or (y > 0 and b[y-1][x]) or b[y][x+1] or (y < GameState.boardY - 1 and b[y+1][x])
        change = true
        adj_ts.unshift([n, x, y])
      else
        adj = false
        for [n1, x1, y1] in adj_ts
          if y == y1
            if x == x1 - 1 or x == x1 + 1
              adj = true
          else if x == x1 and (y == y1 - 1 or y == y1 + 1)
              adj = true
        if adj
          adj_ts.push([n, x, y])
        else
          nadj_ts.push([n, x, y])
        change = adj if adj
    if change
      @reorderTiles(b, adj_ts, nadj_ts)
    else
      adj_ts.concat(ts)

  checkBoard: (b) ->
    ms = GameState.sumEqual
    ml = GameState.maxLength
    mx = GameState.boardX
    my = GameState.boardY

    y = 0
    while y < my
      x = 0
      while x < mx
        s = b[y][x]
        if s
          l = 1
          for i in [1..ml]
            si = b[y][x+i]
            break unless si
            s += si
            l++
          if l > ml
            throw("more than #{ml} consecutive tiles in row #{y} columns #{@translateCol(x)}-#{@translateCol(x+l-1)}")
          if l > 1 and s % ms != 0
            throw("consecutive tiles do not sum to multiple of #{ms} in row #{y} columns #{@translateCol(x)}-#{@translateCol(x+l-1)} sum #{s}")
          x += l
        x++
      y++

    x = 0
    while x < mx
      y = 0
      while y < my
        s = b[y][x]
        if s
          l = 1
          for i in [1..ml]
            si = if b[y+1] then b[y+i][x] else null
            break unless si
            s += si
            l++
          if l > ml
            throw("more than #{ml} consecutive tiles in column #{@translateCol(x)} rows #{y}-#{y+l-1}")
          if l > 1 and s % ms != 0
            throw("consecutive tiles do not sum to multiple of #{ms} in row #{@translateCol(x)} columns #{y}-#{y+l-1} sum #{s}")
          y += l
        y++
      x++


  # Pick a numbered tile from the given rack, removing it from the rack.
  # Throw an error if the tile is not in the rack.
  useRackTile: (rack, n) =>
    for tile, i in rack
      if tile == n
        rack.splice(i, 1)
        return
    throw("attempt to use tile not in rack: tile: #{n}, rack: #{rack}")

  # Return an array showing the number remaining of all tiles in the tile bag
  tileCounts: =>
    counts = {}
    for t in [1..10]
      counts[t] = 0
    for t in @tiles
      counts[t] += 1
    counts

  # Alias for easier use
  print: (x) => process.stdout.write(x)

  # Print the remaining tiles, racks, and board to stdout for debugging
  show: =>
    tc = @tileCounts()

    if @lastMove
      @print("Last Move: #{@lastMove}\n")
      for k, v of @lastRuns
        @print("  #{k}: #{v}\n")
      @print("\n")
    else if @lastMove == null
      @print("Last Move: Pass\n\n")

    @print("Scores:\n")
    for s, i in @scores
      @print("#{@game.players[i].email}: #{s}\n")

    if @gameOver
      @print("\nWinners: #{(p.email for p in @winners).join(', ')}")
    else
      @print("\nCurrent Player: #{@game.players[@toMove].email}")

      @print("\n\nCurrent Rack: ")
      for t in @racks[@toMove]
        @print("#{t} ")

    mx = GameState.boardX
    my = GameState.boardY
    @print("\n\nBoard\n  -")
    for i in [0...mx]
      @print("---")
    for xs, y in @board.slice().reverse()
      y2 = my-y-1
      @print("\n#{if y2 < 10 then " " else ""}#{y2}|")
      for i in xs
        @print("#{if i < 10 then " " else ""}#{i or " "}|")
    @print("\n  |")
    for i in [0...mx]
      @print("--+")
    @print("\n  |")
    for i in [0...mx]
      @print(" #{String.fromCharCode(97+i)}|")
    @print("\n")

class Game
  constructor: (@players) -> @state = GameState.empty(@)

  move: (moves) =>
    @state = @state.move(moves)
    @state.show()

  pass: =>
    @state = @state.pass()
    @state.show()

global.Player = Player
global.Game = Game
global.GameState = GameState
global.g = (new Game [new Player('player1@foo.com'), new Player('player2@bar.com')])
global.m = g.move
g.state.show()
