Q = require './quinto.coffee'

Q.GameState.prototype.print = (x) -> process.stdout.write(x)

Q.GameState.prototype.show = ->
  unless @empty()
    if @lastMove
      @print("Last Move: #{@lastMove}\n")
      for k, v of @lastRuns
        @print("  #{k}: #{v}\n")
      @print("\n")
    else if !(@rack?)
      @print("Last Move: Pass\n\n")

    @print("Scores:\n")
    for s, i in @scores
      @print("#{@game.players[i].email}: #{s}\n")

  if @gameOver
    if @gameWinners
      @print("\nWinners: #{@gameWinners.join(', ')}")
    else
      @print("\nWinners: #{(p.email for p in @winners()).join(', ')}")
  else
    @print("\nCurrent Player: #{@game.players[@toMove].email}")
    if @rack?
      @print("\n\nYour Rack: #{@rack.join(' ')}")
    else
      @print("\n\nCurrent Rack: #{@racks[@toMove].join(' ')}")

  mx = @game.boardX
  my = @game.boardY
  @print("\n\nBoard\n  -")
  for i in [0...mx]
    @print("---")
  for y in [0...my]
    @print("\n#{if y < 10 then " " else ""}#{y}|")
    for x in [0...mx]
      i = @board[@translatePos(x, y)]
      @print("#{if i >= 10 then "" else " "}#{i or " "}|")
  @print("\n  |")
  for i in [0...mx]
    @print("--+")
  @print("\n  |")
  for i in [0...mx]
    @print(" #{String.fromCharCode(97+i)}|")
  @print("\n")

if require.main == module
  # Remote mode using server
  Optimist = require('optimist')
  ARGV = Optimist
    .usage('Play quinto online\nUsage: $0 [options] [url]')
    .demand(['u'])
    .describe('u', 'username/email')
    .describe('p', 'password')
    .describe('g', 'game id')
    .string(['u', 'p', 'g', 'n'])
    .describe('n', 'start new game against other player(s)')
    .describe('r', 'register new user')
    .boolean('r')
    .argv
  Future = require('./future_wrapper')
  Fiber.run ->
    URL = require('url')
    baseUrl = URL.parse(ARGV._[0] || 'http://quinto.herokuapp.com')
    HTTP = require(if baseUrl.protocol == 'https:' then 'https' else 'http')
    Readline = require 'readline'
    Rl = Readline.createInterface(process.stdin, process.stdout)
    QS = require 'querystring'

    question = Future.wrap_wait((q, f) -> Rl.question(q, (n) -> f(null, n)))

    startLoading = -> process.stdout.write("\rLoading...")
    doneLoading =  -> process.stdout.write("\r          \r")

    jsonRequest = (path, opts={}) ->
      fiber = Fiber.current

      for k, v of baseUrl
        opts[k] = v
      opts.path = path

      if playerId && playerToken
        opts.data = {} unless opts.data
        opts.data.playerId = playerId
        opts.data.playerToken = playerToken
        if gameId?
          opts.data.gameId = gameId
      if opts.method == 'POST'
        opts.headers = {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'}
      else if opts.data
        opts.path += "?#{QS.stringify(opts.data)}"
      startLoading()
      req = HTTP.request opts, (res) ->
        fiber.run(res)
      if opts.method == 'POST' && opts.data
        req.write(QS.stringify(opts.data))
      req.end()
      res = yield()
      data = []
      res.on('data', (chunk) -> data.push(chunk))
      res.on('end', -> fiber.run())
      yield()
      doneLoading()
      if res.statusCode == 200
        JSON.parse(data.join(''))
      else
        console.error(data.join(''))
        process.exit(1)

    checkResponse = (obj, action) ->
      unless obj.length == 1 && obj[0].action == action
        console.error("Unexpected response: #{obj}")
        process.exit(1)
      obj

    email = ARGV.u
    unless password = ARGV.p
      password = question('Password: ')

    if ARGV.r
      obj = checkResponse(jsonRequest('/player/register', {method: 'POST', data: {email: email, password: password}}), 'setPlayer')
      console.log("Player registered: #{obj[0].player.email}")
      process.exit(0)

    obj = checkResponse(jsonRequest('/player/login', {method: 'POST', data: {email: email, password: password}}), 'setPlayer')
    obj = obj[0].player
    playerId = obj.id
    playerEmail = obj.email
    playerToken = obj.token
    
    if ARGV.n
      if ARGV.g
        console.log('Cannot specify both -n and -g')
        process.exit(1)
      obj = jsonRequest('/game/new', {method: 'POST', data: {emails: ARGV.n}})
      gameId = obj[0].gameId
    else if ARGV.g
      gameId = ARGV.g
      obj = jsonRequest('/game/join')
    else
      obj = checkResponse(jsonRequest('/game/list'), 'listGames')
      if obj[0].games.length > 0
        console.log('Active Games')
        for game in obj[0].games
          console.log("#{game.id}: #{game.players.join()}")
      else
        console.log('No Active Games')
      process.exit(0)
        

    unless obj[0].action == 'newGame'
        console.error("Unexpected response: #{obj}")
        process.exit(1)

    game = new Q.Game(new Q.Player(email) for email in obj[0].players)
    playerPosition = obj[0].position

    waitFor = (fn) ->
      Future.wait_wrap((ms, f) -> setTimeout(ms))

    handleActions = (actions) ->
      for action in actions
        switch action.action
          when 'updateInfo'
            state = game.state()
            for k, v of action.state
              state[k] = v
            state.show()
            process.exit(0) if state.gameOver
          when 'poll'
            fiber = Fiber.current
            setTimeout((-> fiber.run()), 10000)
            yield()
            handleActions(jsonRequest(action.poll))
          when 'gameOver'
            game.state().gameOver = true
            game.state().gameWinners = action.winners

    handleActions(obj)

    until (state = game.state()).gameOver
      input = question('Move (e.g. 5i8 10i9) or Pass (p): ')
      if input == 'p'
        handleActions(jsonRequest('/game/pass', {method: 'POST'}))
      else
        handleActions(jsonRequest('/game/move', {method: 'POST', data: {move: input}}))

else
  # Local test mode using two players
  global.g = (new Q.Game [new Q.Player('Foo'), new Q.Player('Bar')])
  global.m = (a) ->
    g.move(a)
    g.state().show()
  global.p = ->
    g.pass()
    g.state().show()
  g.state().show()

  process.stdout.write("""
                       To move: m "move1 [move2 ...]"
                       Moves are in the format: tile-column-row
                       For example, to move tile 5 to column i, row 8 (the center): 5i8
                       So a full opening move could be: m "5i8 7i9 3i10"
                       To pass: p()

                       """)
