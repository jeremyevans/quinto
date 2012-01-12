actionHandler = {}

jQuery.fn.serializeObject = ->
  arrayData = @serializeArray()
  objectData = {}

  $.each arrayData, ->
    if @value?
      value = @value
    else
      value = ''

    if objectData[@name]?
      unless objectData[@name].push
        objectData[@name] = [objectData[@name]]

      objectData[@name].push value
    else
      objectData[@name] = value

  return objectData

escape = (s) ->
  $('<div/>').text(s).html()

addToken = (obj) ->
  obj.gameId = window.gameId if window.gameId
  obj.playerId = window.playerId if window.playerId
  obj.playerToken = window.playerToken if window.playerToken
  obj

handleError = (e) ->
  e.error((data) -> $('#current_move').html("<h2>Server Error: #{data.responseText}</h2>"))

request = (path, f) ->
  handleError($.getJSON(path, addToken(if f then f() else {}), handleActions))
  false

post = (path, f) ->
 (e) ->
  e.preventDefault() if e
  handleError($.post(path, addToken(if f then f() else {}), handleActions, 'json'))
    
gameState = -> window.game.state()

handleActions = (actions) ->
  for a in actions
    handleAction(a)

handleAction = (a) ->
  f = actionHandler[a.action]
  if f
    f(a)
  else
    alert("Unhandled action: #{a.action}")

actionHandler.poll = (a) ->
  setTimeout((-> request(a.poll)), 10000)

actionHandler.updateInfo = (a) ->
  gs = gameState()
  for k, v of a.state
    gs[k] = v
  board = gs.board
  tp = gs.translatePos

  board_html = "<table>"
  for y in [0...GameState.boardY]
    board_html += "<tr>"
    for x in [0...GameState.boardX]
      pos = tp(x, y)
      value = board[pos]
      board_html += "<td class='board_tile#{if value then ' fixed' else ''}' id='#{pos}'>#{if value then value else ''}</td>"
    board_html += "</tr>"
  board_html += "</table>"
  $('#board').html(board_html)

  $('#scores').html("<h2>Scores:<h2><table>#{("<tr><td>#{if i == window.playerPosition then 'You' else escape(p)}:</td><td>#{gs.scores[i]}</td></tr>" for p, i in gs.players).join('')}</table>")
  unless window.gameOver
    $('#to_move').html(if gs.toMove == window.playerPosition then 'Your Turn!' else "#{gs.players[gs.toMove]}'s Turn")
    $('#rack').html("<h2>Your Tile Rack:</h2><table><tr>#{("<td class='rack_tile' id='rack#{i}'>#{x}</td>" for x, i in gs.rack).join('')}</tr></table>")
    $('#current_move').html('')
    if window.playerPosition != gs.toMove
      actionHandler.poll(a)
    else
      checkMove()

actionHandler.gameOver = (a) ->
  window.gameOver = true
  $('#to_move, #rack').html('')
  $('#current_move').html("<h2>Game Over!</h2><h2>Winners: #{a.winners.join(', ')}</h2>")

actionHandler.setPlayer = (a) ->
  $('#register').html('')
  $('#login').html('')
  window.playerId = a.player.id
  window.playerToken = a.player.token
  window.playerEmail = a.player.email
  $("#new_game").html("<a href='#'>Start New Game</a>")
  $("#new_game a").click(->
    $('#new_game').html("<form><input name='emails' placeholder='Emails of other players'/><input type='submit' value='Start New Game'/></form>")
    $('#new_game form').submit(post('/game/new', -> $('#new_game form').serializeObject()))
  )
  $("#join_game").html("<a href='#'>Join Game</a>")
  $("#join_game a").click(-> request('/game/list'))
  $("#current_move").html("Thanks for logging in, #{escape(a.player.name)}")
  
actionHandler.newGame = (a) ->
  window.gameId = a.gameId
  window.game = new Game(new Player(p) for p in a.players)
  window.playerPosition = a.position
  $('#login, #register, #new_game, #join_game').remove()

actionHandler.listGames = (a) ->
  options = for g in a.games
    "<option value='#{g.id}'>#{g.id} - #{(pe for pe in g.players when pe != window.playerEmail).join()}</option>"
  $('#join_game').html("<form><select name='gameId'>#{options}</select><input type='submit' value='Join Game'/></form>")
  $("#join_game form").submit(-> request('/game/join', -> $('#join_game form').serializeObject()))

actionHandler.startPage = (a) ->
  $('#register a').click(register)
  $('#login a').click(login)
  $(document).on('click', '.board_tile', '.board_tile', selectTile)
  $(document).on('click', '.rack_tile', '.rack_tile', selectTile)

login = ->
  $('#login').html("<form id='login_form' action='#'><input name='email' placeholder='Email'/><input type='password' name='password' placeholder='Password'/><input type='submit' value='Login'/></form>")
  $('#login_form').submit(post("/player/login", -> $('#login_form').serialize()))

register = ->
  $('#register').html("<form id='register_form' action='#'><input name='name' placeholder='Name'/><input name='email' placeholder='Email'/><input type='password' name='password' placeholder='Password'/><input type='submit' value='Register'/></form>")
  $('#register_form').submit(post("/player/register", -> $('#register_form').serialize()))

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

sendMove = post("/game/move", -> {move: getMove()})

sendPass = post("/game/pass")

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
  gs = gameState()
  if move
    try
      changes = gs.checkMove(move, gs.board, gs.rack)
      $('#current_move').html("<h2>Move Score: #{changes.score}<br />Runs:</h2><table>#{("<tr><td>#{k}:</td><td>#{v}</td></tr>" for k, v of changes.lastRuns).join('')}</table><button type='button' id='commit_move'>Commit Move</button>")
      $('#commit_move').click(sendMove)
    catch error
      $("#current_move").html("<h2>#{error}</h2>")
  else
    $('#current_move').html("<button type='button' id='pass'>Pass#{if gs.passCount == gs.players.length - 1 then ' and End Game' else ''}</button>")
    $('#pass').click(sendPass)

$(document).ready -> actionHandler.startPage()

window.Player = Player
window.Game = Game
window.GameState = GameState
