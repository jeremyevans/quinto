class Player
  constructor: (@name, @email, @token) ->
    throw "player must have a name" unless @name

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

  @centerX: (@boardX-1)/2
  @centerY: (@boardY-1)/2

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

  # Returns number between [-0.5, 0.5]
  @randomSorter: -> 0.5 - Math.random()

  # Create an empty Quinto game
  @empty: (game) =>
    if game.players.length < 2
      throw("must have at least 2 players")
    racks = ([] for p in game.players)
    scores = (0 for p in game.players)
    new @(null, {
      game: game,
      tiles: @tiles.slice().sort(@randomSorter),
      board: {},
      racks: racks,
      scores:scores,
      lastMove: null,
      lastRuns: null,
      passCount: 0,
      moveCount: -1,
      gameOver: false
    })

  # Create a new GameState based on the previous GameState with the given changes
  constructor: (previous, changes) ->
    for own k, v of previous
      unless v instanceof Function
        @[k] = v
    for own k, v of changes
      @[k] = v

    if @gameOver
      throw("Game already ended, can't make more moves")

    @moveCount = @moveCount + 1
    @toMove = @moveCount % @racks.length
    @tiles = @tiles.slice()
    @racks = (@fillRack(rack).sort(@rackSort) for rack in @racks)

    if @passCount == @racks.length
      @gameOver = true
    else
      for x in @racks
        if x.length == 0
          @gameOver = true
    
    # Subtract unplayed tiles from final score
    if @gameOver
      for r, i in @racks
        @scores[i] -= @sum(r)

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
    changes = @checkMove(moves, @board, @racks[@toMove])

    scores = @scores.slice()
    scores[@toMove] += changes.score
    changes.scores = scores
    delete changes.score

    racks = @racks.slice()
    racks[@toMove] = changes.rack
    changes.racks = racks
    delete changes.rack

    new GameState(@, changes)

  checkMove: (moves, b, rack) =>
    board = {}
    for own k, v of b
      board[k] = v
    rack = rack.slice()
    ts = @translateMoves(moves)
    for [n, x, y] in ts
      @useRackTile(rack, n)
    @checkValidMoves(board, ts)
    @checkBoard(board)
    runs = @getRuns(board, ts)
    score = @sum(v for k, v of runs)
    {board: board, rack: rack, score: score, lastMove: moves, lastRuns: runs, passCount: 0}

  # Pass making a move on the board, returning the new GameState
  pass: => new GameState(@, {lastMove: null, lastRuns: null, passCount: @passCount+1})

  empty: => @moveCount - @passCount == 0

  winners: =>
    max = @scores[0]
    for s in @scores
      max = s if s > max
    @game.players[i] for s, i in @scores when s == max

  getRuns: (b, ts) ->
    scores = {}
    if @empty() && ts.length == 1
      scores[@translatePos(ts[0][1], ts[0][2])] = ts[0][0]
    else
      for [n, x, y] in ts
        @xRun(scores, b, y, x) if b[@translatePos(x+1, y)] or b[@translatePos(x-1, y)]
        @yRun(scores, b, y, x) if b[@translatePos(x, y+1)] or b[@translatePos(x, y-1)]
    scores

  xRun: (scores, b, y, x) ->
    xMin = x
    xMax = x
    xMin-- while b[@translatePos(xMin-1, y)]
    xMax++ while b[@translatePos(xMax+1, y)]
    scores["#{y}#{@translateCol(xMin)}-#{@translateCol(xMax)}"] ?= @sum(b[@translatePos(i, y)] for i in [xMin..xMax])

  yRun: (scores, b, y, x) ->
    yMin = y
    yMax = y
    yMin-- while b[@translatePos(x, yMin-1)]
    yMax++ while b[@translatePos(x, yMax+1)]
    scores["#{@translateCol(x)}#{yMin}-#{yMax}"] ?= @sum(b[@translatePos(x, i)] for i in [yMin..yMax])

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

  translatePos: (x, y) => "#{@translateCol(x)}#{y}"
  translateCol: (x) -> String.fromCharCode(x+97)

  checkValidMoves: (b, ts) =>
    mx = GameState.boardX
    my = GameState.boardY
    for [n, x, y] in ts
      if x >= mx or y >= my or x < 0 or y < 0
        throw("attempt to place tile outside of board: pos: #{@translatePos(x, y)}")

    ts = if @empty()
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
      unless @empty() && i == 0
        unless b[@translatePos(x-1, y)] or b[@translatePos(x, y-1)] or b[@translatePos(x+1, y)] or b[@translatePos(x, y+1)]
          throw("attempt to place tile not adjacent to existing tile: pos: #{@translatePos(x, y)}")
      if b[@translatePos(x, y)]
        throw("attempt to place tile over existing tile: pos: #{@translatePos(x, y)} tile: #{n}, existing: #{b[@translatePos(x, y)]}")
      else
        b[@translatePos(x, y)] = n
      i += 1
    if @empty()
      unless b[@translatePos(GameState.centerX, GameState.centerY)]
        throw("opening move must have tile placed in center square (#{@translatePos(GameState.centerX, GameState.centerY)})")
      unless @sum(n for [n, x, y] in ts) % GameState.sumEqual == 0 
        throw("opening move must sum to multiple of #{GameState.sumEqual}")

  reorderTiles: (b, adj_ts, ts) ->
    return adj_ts if ts.length == 0
    nadj_ts = []
    change = false
    for [n, x, y] in ts
      if b[@translatePos(x-1, y)] or b[@translatePos(x, y-1)] or b[@translatePos(x+1, y)] or b[@translatePos(x, y+1)]
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
        s = b[@translatePos(x, y)]
        if s
          l = 1
          for i in [1..ml]
            si = b[@translatePos(x+i, y)]
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
        s = b[@translatePos(x, y)]
        if s
          l = 1
          for i in [1..ml]
            si = b[@translatePos(x, y+i)]
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

class Game
  constructor: (@players) -> @states = [GameState.empty(@)]
  state: => @states[@states.length-1]
  move: (moves) => @states.push(@state().move(moves))
  pass: => @states.push(@state().pass())

if exports?
  exports.Player = Player
  exports.Game = Game
  exports.GameState = GameState
