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

    create_user quinto
    create_db -O quinto quinto
    psql < schema.sql quinto

You need to set the DATABASE\_URL environment variable to a PostgreSQL
connection string before starting the server.

You can then run the server:

    foreman

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

Quinto uses Jasmine for javascript unit tests, ruby for the server unit
tests and the web/integration tests.  You can run all test suites using
the default rake task:

    rake

For the web tests, you need to setup a test database manually first:

    createdb -O quinto quinto_test
    psql -f schema.sql quinto_test

## Source

The most current source code can be accessed via github
(http://github.com/jeremyevans/quinto/).

## Author

Jeremy Evans (code@jeremyevans.net)
