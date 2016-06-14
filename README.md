# Quinto

Quinto is based on the 1960s 3M board game of the same name, simplest to
describe as a numeric version of Scrabble.  This is currently the only
known electronic implementation of Quinto.

## Demo

A demo is available at: http://quinto-demo.jeremyevans.net

## Setup

The server is written in Ruby, so the first step is installing Ruby.

After installing Ruby, install the dependencies:

    gem install -g Gemfile

The server requires a PostgreSQL backend. It's recommended you set up an
application specific server and database:

    createuser quinto
    createdb -O quinto quinto
    for sql in sql/*-*.sql; do
      psql -f $sql quinto
    done

You need to set the QUINTO\_DATABASE\_URL environment variable to a PostgreSQL
connection URL before starting the server.

You can then run the server:

    foreman

## Tests

You can run all test suites using the default rake task:

    rake

For the web tests, you need to setup a test database manually first:

    createdb -O quinto quinto_test
    for sql in sql/*-*.sql; do
      psql -f $sql quinto_test
    done

## Source

The most current source code can be accessed via github
(http://github.com/jeremyevans/quinto/).

## Author

Jeremy Evans (code@jeremyevans.net)
