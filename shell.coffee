Q = require './quinto.coffee'
global.Player = Q.Player
global.Game = Q.Game
global.GameState = Q.GameState

GameState.prototype.print = (x) -> process.stdout.write(x)

GameState.prototype.show = ->
    unless @empty()
      if @lastMove
        @print("Last Move: #{@lastMove}\n")
        for k, v of @lastRuns
          @print("  #{k}: #{v}\n")
        @print("\n")
      else
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
    for y in [0...my]
      @print("\n#{if y < 10 then " " else ""}#{y}|")
      for x in [0...mx]
        i = @board[@translatePos(x, y)]
        @print("#{if i > 10 then "" else " "}#{i or " "}|")
    @print("\n  |")
    for i in [0...mx]
      @print("--+")
    @print("\n  |")
    for i in [0...mx]
      @print(" #{String.fromCharCode(97+i)}|")
    @print("\n")

global.g = (new Q.Game [new Q.Player('player1@foo.com'), new Q.Player('player2@bar.com')])
global.m = (a) ->
  g.move(a)
  g.state().show()
global.p = ->
  g.pass()
  g.state().show()
g.state().show()
