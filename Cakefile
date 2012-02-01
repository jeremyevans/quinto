
spawn = (prog, args) ->
  p = require('child_process').spawn(prog, args)
  p.stdout.on 'data', (data) ->
    process.stdout.write(data)
  p.stderr.on 'data', (data) ->
    process.stderr.write(data)
  p

system = (prog, args, f) ->
  spawn(prog, args).on 'exit', f

task 'spec', 'run the jasmine unit specs', (options) ->
  system 'jasmine-node', ['--coffee', 'spec'], (code) ->

task 'integration', 'run the capybara integration specs', (options) ->
  path = require 'path'
  fs = require 'fs'
  process.env.QUINTO_JSON_ROOT = root = './spec/tmp'
  process.env.QUINTO_PORT = '3001'
  process.env.QUINTO_TEST = '1'
  dirs = for d in ["", "/emails", "/players", "/games"]
    "#{root}#{d}"
  system 'mkdir', dirs, ->
    quinto = spawn('node', ['server.js'])
    system 'rspec', ['spec/integration_spec.rb'], (code) ->
      quinto.kill()
      system 'rm', ['-r', root], ->
