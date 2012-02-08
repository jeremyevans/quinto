Future = require "fibers/future"

Future.wrap_wait = (f, idx=undefined) ->
  v = Future.wrap(f, idx)
  (args...) -> v(args...).wait()

module.exports = Future
