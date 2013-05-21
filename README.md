# Quinto

Quinto is based on the 1960s 3M board game of the same name, simplest to
describe as a numeric version of Scrabble.  This is currently the only
known electronic implementation of Quinto.

## Demo

A demo is available at: http://quinto.herokuapp.com

## Setup

The server is written in Go, so the first step is installing Go.

After installing Go, make sure that the repository is placed in
$GOPATH/src/quinto.  Then install the dependencies:

    go get

Then install the executable:

    go install quinto

The server requires a PostgreSQL backend, which you can initialize via:

    create_db quinto
    psql < schema.sql quinto

You may need to set the DATABASE\_CONFIG environment variable to a PostgreSQL
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
integration tests.  You can run all test suites using the default rake
task:

    rake

## Source

The most current source code can be accessed via github
(http://github.com/jeremyevans/quinto/).

## Author

Jeremy Evans (code@jeremyevans.net)
