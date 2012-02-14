# Quinto

Quinto is based on the 1960s 3M board game of the same name, simplest to
describe as a numeric version of Scrabble.  This is currently the only
known electronic implementation of Quinto.

## Setup

The Quinto server is a nodejs application, so you'll need to install
nodejs first.  After installing node, run:

    npm install

That will install the other dependencies (coffeescript, express,
bcrypt, and fibers).  The default persistence backend uses JSON files
in the filesystem, and you can create the necessary directory
structure via:

    mkdir tmp/{,emails,players,games}

There is also a PostgreSQL backend, which you can use via:

    npm install pg
    create_db quinto
    psql < schema.sql quinto

To enable the PostgreSQL backend, set the DATABASE_URL environment
variable before running the app.

## Running

To run the app:

    node server.js

or:

    coffee app.coffee

By default, the server runs on port 3000, you can set the QUINTO_PORT
environment variable to override it.

## Design

Quinto is designed as a single page application.  Registration
requires a password, which is hashed with bcrypt.  The password is
used for initial login, but after that, a randomly generated token is
used for authentication.

## Tests

Quinto uses Jasmine for unit tests and capybara (written in ruby) for
integration tests.  You can run all test suites using the cake all
task.

## Source

The most current source code can be accessed via github
(http://github.com/jeremyevans/quinto/).

## Todo

* CLI interface

## Author

Jeremy Evans (code@jeremyevans.net)
