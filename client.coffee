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
  obj.gameId or= window.gameId if window.gameId
  obj.playerId = window.playerId if window.playerId
  obj.playerToken = window.playerToken if window.playerToken
  obj

handleError = (e) ->
  e.error((data) -> $('#current_move').html("<h2>Server Error: #{data.responseText}</h2>"))

request = (path, f=null, opts={}) ->
  opts.url = path
  opts.dataType = 'json'
  opts.cache = false
  opts.success = handleActions
  opts.data = addToken(if f then f() else {})
  handleError($.ajax(opts))
  false

post = (path, f=null, opts={}) ->
 (e) ->
  e.preventDefault() if e
  request(path, f, {type: 'POST'})
    
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
  i = window.gameId
  setTimeout((-> request(a.poll) if window.gameId == i), 10000)

myTurn = ->
  window.playerPosition == gameState().toMove

actionHandler.updateInfo = (a) ->
  gs = gameState()
  oldBoard = gs.board
  for k, v of a.state
    gs[k] = v
  board = gs.board
  tp = gs.translatePos

  board_html = "<table>"
  for y in [0...Game.boardY]
    board_html += "<tr>"
    for x in [0...Game.boardX]
      pos = tp(x, y)
      value = board[pos]
      board_html += "<td class='board_tile"
      if value
        board_html += ' fixed'
        unless oldBoard[pos]
          board_html += ' last'
      board_html += "' id='#{pos}'>"
      if value
        board_html += value
      board_html += "</td>"
    board_html += "</tr>"
  board_html += "</table>"
  $('#board').html(board_html)

  $('#scores').html("<h2>Scores:<h2><table>#{("<tr><td>#{if i == window.playerPosition then 'You' else escape(p.email)}:</td><td>#{gs.scores[i]}</td></tr>" for p, i in window.game.players).join('')}</table>")
  unless window.gameOver
    $('#to_move').html(if myTurn() then 'Your Turn!' else "#{window.game.players[gs.toMove].email}'s Turn")
    $('#rack').html("<div id='tile_holder'>#{("<div class='rack_tile' id='rack#{i}'>#{x}</div>" for x, i in gs.rack).join('')}</div><h2>Your Tile Rack</h2>")
    $('#current_move').html('')
    if myTurn()
      $('.rack_tile').draggable({cursor: 'move', helper: 'clone'})
      $('.board_tile').droppable(drop: droppedTile)
      checkMove()

droppedTile = (e, ui) ->
  b = $(@)

  unless b.hasClass('fixed')
    r = ui.draggable
    $('.current').removeClass('current')
    b.addClass('current')
    r.addClass('current')

    if r2 = b.data('assoc')
      r2.data('assoc', null)
      r2.removeClass('move')
    if b2 = r.data('assoc')
      b2.html('')
      b2.data('assoc', null)
      b2.removeClass('move')

    processTiles()

actionHandler.gameOver = (a) ->
  window.gameOver = true
  $('#to_move, #rack').html('')
  $('#current_move').html("<h2>Game Over!</h2><h2>Winners: #{a.winners.join(', ')}</h2>")

actionHandler.setPlayer = (a) ->
  $('#login, #register').html('')
  $('#logout').html("<h2><a href='#'>Logout</a></h2>")
  $('#logout a').click(logout)
  window.playerId = a.player.id
  window.playerToken = a.player.token
  window.playerEmail = a.player.email
  initPlayer()

initPlayer = ->
  window.gameOver = false
  window.gameId = null
  window.game = null
  window.playerPosition = null
  $("#new_game").html("<a href='#'>Start New Game</a>")
  $("#new_game a").click ->
    $('#new_game').html("<form><input name='emails' placeholder='Usernames/Emails of other players' size='40'/><input type='submit' value='Start New Game'/></form>")
    $('#new_game form').submit(post('/game/new', -> $('#new_game form').serializeObject()))
  $("#join_game").html("<a href='#'>Join Game</a>")
  $("#join_game a").click(-> request('/game/list'))
  $("#current_move").html("Thanks for logging in, #{escape(window.playerEmail)}")
  $('#leave_game, #board, #rack, #scores').html('')
  
actionHandler.newGame = (a) ->
  window.gameId = a.gameId
  window.game = new Game(new Player(p) for p in a.players)
  window.playerPosition = a.position
  $('#new_game, #join_game').html('')
  $("#leave_game").html("<h2><a href='#'>Leave Game</a></h2>")
  $("#leave_game a").click(initPlayer)

actionHandler.listGames = (a) ->
  options = for g in a.games
    "<option value='#{g.id}'>#{g.id} - #{(pe for pe in g.players when pe != window.playerEmail).join('')}</option>"
  $('#join_game').html("<form><select name='gameId'>#{options}</select><input type='submit' value='Join Game'/></form>")
  $("#join_game form").submit(-> request('/game/join', -> $('#join_game form').serializeObject()))

logout = ->
  window.playerId = null
  window.playerToken = null
  window.playerEmail = null
  window.gameId = null
  $('#logout').html("")
  $('#leave_game').html("")
  $('#login').html("<a href='#'>Login</a>")
  $('#register').html("<a href='#'>Register</a>")
  $('#board, #rack, #new_game, #join_game, #to_move, #scores, #current_move').html('')
  $('#login a').click(login)
  $('#register a').click(register)

startPage = (a) ->
  logout()
  $('#rules a').click(showRules)
  $(document).on('click', '.board_tile', '.board_tile', selectTile)
  $(document).on('click', '.rack_tile', '.rack_tile', selectTile)

hideRules = ->
  $("#rules").html("<h2 class='link'><a href='#'>Rules</a></h2>")
  $("#rules a").click(showRules)

showRules = ->
  $('#rules').html("
    <h2 class='link'><a href='#'>Hide Rules</a></h2>

    <h2>How to Play Quinto</h2>

    <h3>Object of the Game</h3>

    <p>Each player, in turn, tries to play from one to five tiles
    in a row, either rank or file, with at least one of his tiles
    touching one previously played.  The face numbers on the tile
    must total 5 or a multiple of 5 in all directions (just as a
    crossword puzzle must make sense in all directions).  Each
    player scores the total of the face numbers in rows he has
    completed.  High scorer wins.</p>

    <h3>Play</h3>

    <p><b>First player</b>: Place from one to five of your tiles in a straight
    line, either rank (across) or file (down).  One of these played
    tiles must be placed on the center square of the board.  The face
    numbers must total 5 or a multiple of 5 (10, 15, etc.).  After
    playing, draw again to keep a total of five tiles before you.</p>

    <p><b>Other players</b>: Do the same, placing at least one of your
    tiles touching one previously placed.  The tiles must total 5 or a
    multiple of 5 in all directions.</p>

    <p>A short row (fewer than five) may be extended by another player.
    A row may never contain more than 5 tiles.  If it is your turn, you
    can choose to pass instead of making a move on the board.</p>

    <h3>Scoring</h3>

    <p>Your score is the same as the total of the face numbers on the
    tiles in all of the rows you have completed.  Although you must play
    your tiles in only one direction in one turn, you will discover it
    is possible to score in several directions at once.</p>

    <p>When all of the playable tiles have been used, the player with the
    highest score wins.  Any unplayed tiles are subtracted from the holder's
    score.</p>")
  $('#rules a').click(hideRules)

login = ->
  $('#login').html("<form id='login_form' action='#'><input name='email' placeholder='Username/Email'/><input type='password' name='password' placeholder='Password'/><input type='submit' value='Login'/></form>")
  $('#login_form').submit(post("/player/login", -> $('#login_form').serialize()))

register = ->
  $('#register').html("<form id='register_form' action='#'><input name='email' placeholder='Username/Email'/><input type='password' name='password' placeholder='Password'/><input type='submit' value='Register'/></form>")
  $('#register_form').submit(post("/player/register", -> $('#register_form').serialize()))

selectTile = (e) ->
  return unless myTurn()
  exist = $(e.data)
  t = $(e.target)
  if t.hasClass('current')
    t.removeClass('current')
  else if t.hasClass('fixed')
    # Ignore, can't operate on already placed tile
    null
  else
    exist.filter('.current').removeClass('current')
    d = t.data('assoc')
    if t.hasClass('move')
      # If already in move, remove
      if e.data == '.board_tile'
        t.html('')
      else if d?
        d.html('')
      if d?
        d.removeClass('move')
      t.removeClass('move')
    t.addClass('current')
    $("#current_move").html('')
    processTiles()

getMove = ->
  $('.rack_tile.move').filter(->
    $(@).data('assoc')?
  ).map(->
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
    $('#current_move').html("<button type='button' id='pass'>Pass#{if gs.passCount == window.game.players.length - 1 then ' and End Game' else ''}</button>")
    $('#pass').click(sendPass)

$(document).ready -> startPage()

window.Player = Player
window.Game = Game
window.GameState = GameState
