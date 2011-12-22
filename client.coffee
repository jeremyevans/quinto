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

actionHandler.drawBoard = (a) ->
  $('body').html("<h1 id='title'>Quinto</h1>")
  $('#title').after("<div id='board'><table>#{("<tr>#{("<td>#{if x then x else ''}</td>" for x in xs).join('')}</tr>" for xs in a.board).join('')}</table></div>")

actionHandler.drawRack = (a) ->
  $('#board').after("<div id='rack'><table><tr>#{("<td>#{x}</td>" for x in a.rack).join('')}</tr></table></div>")

actionHandler.startPage = (a) ->
  $('body').html("<h1 id='title'>Quinto</h1><h2><a id='new_game' href='#'>Start New Game</a></h2>")
  $('#new_game').click(-> request("/game/new"))

$(document).ready -> actionHandler.startPage()

