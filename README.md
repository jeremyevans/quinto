# Quinto

Quinto is based on the 1960s 3M board game of the same name, simplest to
describe as a numeric version of Scrabble.  This is currently the only
known electronic implementation of Quinto.

## Demo

A demo is available at: http://quinto.herokuapp.com

You can access the server via a browser or the included command line
client to play online against other users.

## Included

Included are the following implementations:

1) Command Line Client written in CoffeeScript/NodeJS
2) Server written in CoffeeScript/NodeJS
3) Server written in Go

Both servers operate roughly the same way, you only need to run one of
them.

## Setup - NodeJS

After installing NodeJS, run:

    npm install

That will install the other dependencies (pg, coffeescript, express,
bcrypt, and fibers).  The default persistence backend uses JSON files
in the filesystem, and you can create the necessary directory
structure via:

    mkdir tmp/{,emails,players,games}

There is also a PostgreSQL backend, which you can use via:

    create_db quinto
    psql < schema.sql quinto

To enable the PostgreSQL backend, set the DATABASE_URL environment
variable before running the app.

The command line interface requires optimist:

    npm install optimist

This is only required if want to connect to a remote server using
the command line interface.

## Running the NodeJS Server

To run the NodeJS Quinto server:

    node server.js

or:

    coffee app.coffee

By default, the server runs on port 3000, you can set the PORT
environment variable to override it.

## Running the command line client

The shell.coffee file includes two ways of playing on the command
line:

* Local mode, giving you a coffee REPL, and allowing you to play
  both sides of a two person game.
* Remote mode, allowing you to connect to a server, and play against
  other users (who may be using a browser or the command line
  interface)

For local mode, just start coffee and require the file:

    coffee -r ./shell.coffee

For remote mode, you can pass some options and a URL:

    Usage: coffee ./shell.coffee [options] [url]
    
    Options:
      -u  username/email                         [string]  [required]
      -p  password                               [string]
      -g  game id                                [string]
      -n  start new game against other player(s) [string]
      -r  register new user                      [boolean]

If you don't provide a URL, it will use the demo server at
http://quinto.herokuapp.com as the server.

If you don't provide a game id, it will show you a list
of game ids and related player emails, and you can then run the
client again providing the gameId.

If you don't provide the password on the command line (which is
a good idea for security reasons), it will prompt you to enter one.

## Setup - Go

After installing Go, make sure that the repository is placed in
$GOPATH/src/quinto.  Then install the dependencies:

    go get

You can then install the executable:

    go install quinto

The Quinto Go server requires a PostgreSQL backend, which you can initialize
via:

    create_db quinto
    psql < schema.sql quinto

You may need to set the DATABASE_CONFIG environment variable to a PostgreSQL
connection string before starting the server, see
https://github.com/bmizerany/pq for details about connection strings.

You can then run the server:

    $GOPATH/bin/quinto

## Security

Quinto is designed as a single page application.  Registration
requires a password, which is hashed with bcrypt.  The password is
used for initial login, but after that, a randomly generated token is
used for authentication.  The token is currently per user, a more
secure method would be to generate a random token per user per game.

Obviously, to have any security at all, you have to host the server
using SSL.  The default app does not do this, you need to put a
reverse proxy (e.g. nginx) in front of the app to handle SSL.  The
demo app also does not do this, and should be considered insecure.

## Tests

Quinto uses Jasmine for unit tests and capybara (written in ruby) for
integration tests.  You can run all test suites using the cake all
task.

## Source

The most current source code can be accessed via github
(http://github.com/jeremyevans/quinto/).

## Author

Jeremy Evans (code@jeremyevans.net)
