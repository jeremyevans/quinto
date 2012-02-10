
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
  process.env.QUINTO_PORT or= '3001'
  process.env.QUINTO_TEST or= '1'
  quinto = spawn('node', ['server.js'])
  system 'rspec', ['spec/integration_spec.rb'], (code) ->
    quinto.kill()
    f()

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

task 'spec', 'run the jasmine unit specs', (options) ->
  spec ->

task 'integration_json', 'run the capybara integration specs', (options) ->
  integration_json ->

task 'integration_pg', 'run the capybara integration specs', (options) ->
  integration_pg ->

task 'all', (options) ->
  spec ->
    integration_json ->
      integration_pg ->
