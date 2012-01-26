Q = require '../quinto'
Player = Q.Player
Game = Q.Game
GameState = Q.GameState

describe 'Player', ->
  it 'should have a working constructor', ->
    p = new Player 'foo', 'bar@baz.com', 'blah'
    expect(p.name).toEqual 'foo'
    expect(p.email).toEqual 'bar@baz.com'
    expect(p.token).toEqual 'blah'

describe 'Game', ->
  beforeEach ->
    @g = new Game [new Player('foo', 'bar@baz.com', 'blah'), new Player('foo2', 'bar2@baz.com', 'blah2')]
    @s = @g.state()

  it 'should require at least 2 players', ->
    expect(-> new Game []).toThrow()
    expect(-> new Game [new Player 'foo', 'bar@baz.com', 'blah']).toThrow()

  it 'should have an initial state', ->
    expect(@s.tiles.length).toEqual(80)
    expect(@s.racks.length).toEqual(2)
    expect(r.length).toEqual(5) for r in @s.racks

  it 'should allow passing', ->
    expect(@s.toMove).toEqual(0)
    @g.pass()
    s = @g.state()
    expect(s.toMove).toEqual(1)
    expect(s.scores).toEqual([0, 0])

  it 'should allow moving', ->
    expect(@s.toMove).toEqual(0)
    @s.racks[0][1] = 5
    @g.move("5i8")
    s = @g.state()
    expect(s.toMove).toEqual(1)
    expect(s.scores).toEqual([5, 0])

describe 'GameState', ->
  beforeEach ->
    @s = (new Game [new Player('foo', 'bar@baz.com', 'blah'), new Player('foo2', 'bar2@baz.com', 'blah2')]).state()
    @s.racks = [[5, 6, 4, 3, 7], [5, 8, 2, 9, 1]]

  it 'should have a reasonable initial state', ->
    expect(@s.tiles.length).toEqual(80)
    expect(@s.racks.length).toEqual(2)
    expect(r.length).toEqual(5) for r in @s.racks
    expect(@s.game.players[0].name).toEqual('foo')
    expect(@s.board).toEqual({})
    expect(@s.scores).toEqual([0, 0])
    expect(@s.lastMove).toEqual(null)
    expect(@s.lastRuns).toEqual(null)
    expect(@s.passCount).toEqual(0)
    expect(@s.moveCount).toEqual(0)
    expect(@s.gameOver).toEqual(false)

  it 'should have a reasonable state after passing', ->
    s = @s.pass()
    expect(s.tiles.length).toEqual(80)
    expect(s.racks.length).toEqual(2)
    expect(r.length).toEqual(5) for r in s.racks
    expect(s.game.players[0].name).toEqual('foo')
    expect(s.board).toEqual({})
    expect(s.scores).toEqual([0, 0])
    expect(s.lastMove).toEqual(null)
    expect(s.lastRuns).toEqual(null)
    expect(s.passCount).toEqual(1)
    expect(s.moveCount).toEqual(1)
    expect(s.gameOver).toEqual(false)

  it 'should have a reasonable state after moving', ->
    s = @s.move('5i8')
    expect(s.tiles.length).toEqual(79)
    expect(s.racks.length).toEqual(2)
    expect(r.length).toEqual(5) for r in s.racks
    expect(s.game.players[0].name).toEqual('foo')
    expect(s.board).toEqual({i8: 5})
    expect(s.scores).toEqual([5, 0])
    expect(s.lastMove).toEqual('5i8')
    expect(s.lastRuns).toEqual({i8: 5})
    expect(s.passCount).toEqual(0)
    expect(s.moveCount).toEqual(1)
    expect(s.gameOver).toEqual(false)

  it 'should be over if all players pass', ->
    expect(@s.pass().pass().gameOver).toEqual(true)

  it 'should be over if all tiles are played and a rack is empty', ->
    @s.tiles = []
    s = @s.move('6i8 5i7 4i6 3i5 7i4')
    expect(s.gameOver).toEqual(true)
    expect(s.scores).toEqual([25, -25])

  it 'should report winners correctly', ->
    expect(p.name for p in @s.pass().pass().winners()).toEqual(['foo', 'foo2'])
    @s.racks[0] = [5]
    @s.tiles = []
    expect(p.name for p in @s.move('5i8').winners()).toEqual(['foo'])

  it 'should report if the board is empty', ->
    expect(@s.empty()).toEqual(true)
    expect(@s.pass().empty()).toEqual(true)
    expect(@s.move('5i8').empty()).toEqual(false)

  it 'should throw error if first move not in center', ->
    expect(=> @s.move('5i7')).toThrow()

  it 'should throw error if tile played not adjacent to existing tile', ->
    expect(=> @s.move('5i7 6i9 4i10')).toThrow()
    s = @s.move('5i8 6i9 4i10')
    expect(-> s.move('5i5')).toThrow()

  it 'should throw error if sum of any run does not equal multiple of 5', ->
    expect(=> @s.move('5i8 6i9')).toThrow()
    s = @s.move('5i8 6i9 4i10')
    expect(-> s.move('5j10')).toThrow()

  it 'should throw error if more than 5 tiles in a row', ->
    s = @s.move('5i8 6i9 4i10 7i11 3i12')
    expect(-> s.move('5i13')).toThrow()

  it 'should throw error if tile played not in rack', ->
    expect(=> @s.move('10i8')).toThrow()

  it 'should throw error if tile played outside of board', ->
    expect(=> @s.move('5i20')).toThrow()
    s = @s.move('5i8')
    s.board = {i16: 5}
    expect(-> s.move('5i17')).toThrow()

  it 'should throw error if tiles not in single row or column', ->
    expect(=> @s.move('5i8 6i9 4j9')).toThrow()
    expect(=> @s.move('5i8 6j8 4j9')).toThrow()

  it 'should throw error if tile played over existing tile', ->
    s = @s.move('5i8')
    expect(-> s.move('5i8')).toThrow()

  it 'should calculate runs correctly', ->
    s = @s.move('5i8 6i9 7i10 4i11 3i12')
    expect(s.scores).toEqual([25, 0])
    expect(s.move('5j8 9j9 8j10 2j7 1j6').scores).toEqual([25, 65])
