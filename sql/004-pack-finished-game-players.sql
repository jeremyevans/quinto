BEGIN;

ALTER TABLE games ADD COLUMN player_ids integer[];

CREATE INDEX player_ids_idx ON games USING GIN (player_ids);

UPDATE games SET player_ids = (SELECT array_agg(player_id ORDER BY position) FROM game_players WHERE game_id = games.id);

DROP TABLE game_players;

COMMIT;
