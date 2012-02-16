CREATE TABLE players (
  id SERIAL PRIMARY KEY
 ,email TEXT NOT NULL
 ,hash TEXT NOT NULL
 ,token TEXT NOT NULL
);
CREATE UNIQUE INDEX players_email_idx ON players(email);

CREATE TABLE games (
  id SERIAL PRIMARY KEY
);

CREATE TABLE game_players (
  game_id INTEGER REFERENCES games
 ,player_id INTEGER REFERENCES players
 ,position INTEGER NOT NULL
 ,PRIMARY KEY (game_id, player_id)
);
CREATE UNIQUE INDEX game_players_game_id_position_idx ON game_players(game_id, position);

CREATE TABLE game_states (
  game_id INTEGER REFERENCES games 
 ,move_count INTEGER
 ,to_move INTEGER NOT NULL
 ,tiles TEXT NOT NULL
 ,board TEXT NOT NULL
 ,last_move TEXT
 ,pass_count INTEGER NOT NULL
 ,game_over BOOLEAN NOT NULL
 ,racks TEXT NOT NULL
 ,scores TEXT NOT NULL
 ,PRIMARY KEY (game_id, move_count)
);
CREATE INDEX game_states_last_move_idx ON game_states(game_id, move_count DESC);

