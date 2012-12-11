
spawn = (prog, args) ->
  console.log("#{prog} #{args.join(' ')}")
  p = require('child_process').spawn(prog, args)
  p.stdout.on 'data', (data) ->
    process.stdout.write(data)
  p.stderr.on 'data', (data) ->
    process.stderr.write(data)
  p

system = (prog, args, f) ->
  spawn(prog, args).on 'exit', f

spec = (f) ->
  system 'jasmine-node', ['--coffee', 'spec'], f

integration = (f) ->
  process.env.PORT or= '3001'
  process.env.QUINTO_TEST or= '1'
  quinto = if process.env.QUINTO_SERVER == 'go'
    spawn("#{process.env.GOPATH}/bin/quinto", [])
  else
    spawn('node', ['server.js'])
  setTimeout (->
    system 'rspec', ['-b', 'spec/integration_spec.rb'], (code) ->
      quinto.kill('SIGKILL')
      f()
    ), 3000

integration_json = (f) ->
  path = require 'path'
  fs = require 'fs'
  root = process.env.QUINTO_JSON_ROOT or= './spec/tmp'
  dirs = for d in ["", "/emails", "/players", "/games"]
    "#{root}#{d}"
  system 'mkdir', dirs, ->
    integration ->
      system 'rm', ['-r', root], f

integration_pg = (f) ->
  user = process.env.PGUSER or= 'postgres'
  db = process.env.PGDATABASE or= 'quinto_test'
  host = process.env.PGHOST or= 'localhost'
  process.env.DATABASE_URL or= "postgres://#{user}@#{host}/#{db}"
  system 'dropdb', ['quinto_test'], (code) ->
    system 'createdb', ['quinto_test'], (code) ->
      system 'psql', ['-f', 'schema.sql', 'quinto_test'], (code) ->
        integration ->
          system 'dropdb', ['quinto_test'], f

spec_go = (f) ->
  system 'go', ['test', './quinto'], f

integration_go = (f) ->
  process.env.QUINTO_SERVER or= 'go'
  system 'go', ['install', 'quinto'], (code) ->
    integration_pg ->

task 'spec', 'run the node unit specs', (options) ->
  spec ->

task 'integration_json', 'run the capybara integration specs with node/json', (options) ->
  integration_json ->

task 'integration_pg', 'run the capybara integration specs with node/PostgreSQL', (options) ->
  integration_pg ->

task 'spec_go', 'run the go unit specs', (options) ->
  spec_go ->

task 'integration_go', 'run the capybara integration specs with go/PostgreSQL', (options) ->
  integration_go ->

task 'app.js', 'regenerate the app.js file', (options) ->
  system 'sh', ['-c', 'cat client.coffee quinto.coffee | coffee -cs > public/app.js'], (code) ->

task 'all', (options) ->
  spec ->
    spec_go ->
      integration_json ->
        integration_pg ->
          integration_go ->

