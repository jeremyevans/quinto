class Player
  constructor: (@email) ->

class GameState
  # Number of tiles each player has at one time
  @rackSize: 5

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
    new @(null, {game: game, tiles: @tiles, board: @emptyBoard, toMove: -1, racks: racks})

  # Create a new GameState based on the previous GameState with the given changes
  constructor: (@previous, changes) ->
    for own k, v of changes
      @[k] = v
    for own k, v of previous
      unless v instanceof Function
        @[k] ?= v
    @toMove = (@toMove + 1) % @racks.length
    @tiles = @tiles.slice()
    @racks = (@fillRack(rack).sort(@rackSort) for rack in @racks)

  # Sort function for rack tiles
  rackSort: (a, b) -> parseInt(a, 10) - parseInt(b, 10)

  # Fill the rack so that it has rackSize number of tiles
  fillRack: (rack) =>
    rack.concat(@takeTiles(GameState.rackSize - rack.length))

  # Remove i number of tiles from the tile bag
  takeTiles: (i) =>
    t = []
    for j in [0...i]
      t.push(@tiles.splice(Math.floor(Math.random() * @tiles.length), 1)[0])
    t

  # Make a move on the board, returning the new GameState
  move: (ts) =>
    b = (xs.slice() for xs in @board)
    racks = @racks.slice()
    racks[@toMove] = racks[@toMove].slice()
    rack = racks[@toMove]
    for [n, x, y] in ts
      @useRackTile(rack, n)
      b[y][x] = n
    new GameState(@, {board: b, racks: racks})

  # Pass making a move on the board, returning the new GameState
  pass: => new GameState(@, {})

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
    @print("Tiles\n")
    for i in [1..10]
      @print("#{i}: #{tc[i]}, ")

    @print("\n\nRacks")
    for r, i in @racks
      @print("\n#{if i == @toMove then "*" else " "}#{i+1}: ")
      for t in r
        @print("#{t} ")
      @print(@game.players[i].email)

    @print("\n\nBoard\n    |")
    for i in [0...GameState.boardX]
      @print(" #{if i < 10 then " " else ""}#{i} |")
    for xs, j in @board
      @print("\n #{if j < 10 then " " else ""}#{j} |")
      for i in xs
        @print(" #{if i < 10 then " " else ""}#{i or " "} |")
    @print("\n")

class Game
  constructor: (@players) -> @state = GameState.empty(@)
  move: (tiles) => @state = @state.move(tiles)
  pass: => @state = @state.pass()

global.Player = Player
global.Game = Game
global.g = (new Game [new Player('player1@foo.com'), new Player('player2@bar.com')])
g.state.show()
