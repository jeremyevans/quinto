
system = (prog, args, f) ->
  p = require('child_process').spawn(prog, args)
  p.stdout.on 'data', (data) ->
    process.stdout.write(data)
  p.stderr.on 'data', (data) ->
    process.stderr.write(data)
  p.on 'exit', f

task 'spec', 'run the jasmine specs', (options) ->
  system 'jasmine-node', ['--coffee', 'spec'], (code) ->

