actionHandler = {}

request = (path) ->
  $.getJSON(path, handleActions)
  false

handleActions = (actions) ->
  for a in actions
    handleAction(a)

handleAction = (a) ->
  f = actionHandler[a.action]
  if f
    f(a)
  else
    alert("Unhandled action: #{a.action}")

gameState = -> window.game.state

actionHandler.poll = (a) ->
  setTimeout((->
    $.getJSON(a.poll, handleActions)
  ), 10000)

actionHandler.updateInfo = (a) ->
  gs = gameState()
  for k, v of a.state
    gs[k] = v
  tp = gs.translatePos
  $('#to_move').html(if gs.toMove == gs.playerId then 'Your Turn!' else "#{gs.players[gs.toMove]}'s Turn")
  $('#board').html("<table>#{("<tr>#{("<td class='board_tile#{if i then ' fixed' else ''}' id='#{tp(x, y)}'>#{if i then i else ''}</td>" for i, x in xs).join('')}</tr>" for xs, y in gs.board).join('')}</table>")
  $('#rack').html("<h2>Your Tile Rack:</h2><table><tr>#{("<td class='rack_tile' id='rack#{i}'>#{x}</td>" for x, i in gs.rack).join('')}</tr></table>")
  $('#scores').html("<h2>Scores:<h2><table>#{("<tr><td>#{if i == gs.playerId then 'You' else p}:</td><td>#{gs.scores[i]}</td></tr>" for p, i in gs.players).join('')}</table>")
  $('#current_move').html('')
  if gs.playerId != gs.toMove
    actionHandler.poll(a)

actionHandler.newGame = (a) ->
  window.game = new Game(new Player(p) for p in a.players)
  $('.join').remove()

actionHandler.startPage = (a) ->
  $('#join_game0').click(-> request("/game/join/0"))
  $('#join_game1').click(-> request("/game/join/1"))
  $(document).on('click', '.board_tile', '.board_tile', selectTile)
  $(document).on('click', '.rack_tile', '.rack_tile', selectTile)

selectTile = (e) ->
  exist = $(e.data)
  t = $(e.target)
  if t.hasClass('current')
    t.removeClass('current')
  else if t.hasClass('fixed')
    # Ignore, can't operate on already placed tile
    null
  else
    exist.filter('.current').removeClass('current')
    if t.hasClass('move')
      # If already in move, remove
      if e.data == '.board_tile'
        t.html('')
      else
        t.data('assoc').html('')
      t.data('assoc').removeClass('move')
      t.removeClass('move')
    t.addClass('current')
    $("#current_move").html('')
    processTiles()

getMove = ->
  $('.rack_tile.move').map(->
    t = $(@)
    "#{t.html()}#{t.data('assoc').attr('id')}"
  ).get().join(' ')

sendMove = ->
  gs = gameState()
  $.post("/game/move/#{gs.playerId}", {move: getMove()})
    .success(handleActions)
    .error((data) -> $('#current_move').html("<h2>Server Error: #{data.responseText}</h2>"))

processTiles = ->
  b = $('.board_tile.current')
  r = $('.rack_tile.current')
  if b.length > 0 and r.length > 0
    b.html(r.html())
    b.data('assoc', r)
    r.data('assoc', b)
    b.add(r).addClass('move').removeClass('current')
  checkMove()

checkMove = ->
  move = getMove()
  if move
    gs = gameState()
    try
      changes = gs.checkMove(move, gs.board, gs.rack)
      $('#current_move').html("<h2>Move Score: #{changes.score}<br />Runs:</h2><table>#{("<tr><td>#{k}:</td><td>#{v}</td></tr>" for k, v of changes.lastRuns).join('')}</table><button type='button' id='commit_move'>Commit Move</button>")
      $('#commit_move').click(sendMove)
    catch error
      $("#current_move").html("<h2>#{error}</h2>")


$(document).ready -> actionHandler.startPage()

window.Player = Player
window.Game = Game
window.GameState = GameState
