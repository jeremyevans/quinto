Future = require "fibers/future"

Future.wrap_wait = (f) ->
  v = Future.wrap(f)
  (args...) -> v(args...).wait()

module.exports = Future
