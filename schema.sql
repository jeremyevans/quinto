CREATE TABLE players (
  id SERIAL PRIMARY KEY
 ,name TEXT NOT NULL
 ,email TEXT NOT NULL
 ,hash TEXT NOT NULL
 ,token TEXT NOT NULL
);
CREATE UNIQUE INDEX players_email_idx on players(email);

CREATE TABLE games (
  id SERIAL PRIMARY KEY
 ,player_ids INTEGER[] NOT NULL
);

CREATE TABLE game_states (
  game_id INTEGER REFERENCES games 
 ,move_count INTEGER
 ,to_move INTEGER NOT NULL
 ,tiles INTEGER[] NOT NULL
 ,board TEXT NOT NULL
 ,last_move TEXT
 ,pass_count INTEGER NOT NULL
 ,game_over BOOLEAN NOT NULL
 ,racks INTEGER[][] NOT NULL
 ,scores INTEGER[] NOT NULL
 ,PRIMARY KEY (game_id, move_count)
);
CREATE INDEX game_states_last_move_idx ON game_states(game_id, move_count DESC);

