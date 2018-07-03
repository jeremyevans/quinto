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

You need to set the following environment variables:

QUINTO\_DATABASE\_URL :: PostgreSQL database connection URL
QUINTO\_SESSION\_CIPHER\_SECRET :: 32 byte randomly generated secret
QUINTO\_SESSION\_HMAC\_SECRET :: >=32 byte randomly generated secret

One way to set this is to create a .env.rb file in the root of the repository
containing:

    ENV['QUINTO_DATABASE_URL'] ||= 'postgres:///?user=quinto&password=...'
    ENV['QUINTO_SESSION_CIPHER_SECRET'] ||= '...'
    ENV['QUINTO_SESSION_HMAC_SECRET'] ||= '...'

You can then run the server (via unicorn or another rack-compatible webserver):

    unicorn

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
