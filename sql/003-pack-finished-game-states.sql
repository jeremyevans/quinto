BEGIN;

ALTER TABLE games ADD COLUMN finished_game_states game_states[];

UPDATE games SET finished_game_states = (SELECT array_agg(game_states ORDER BY move_count) FROM game_states WHERE game_id = games.id) WHERE id IN (SELECT game_id FROM game_states WHERE game_over);

DELETE FROM game_states WHERE game_id IN (SELECT game_id FROM game_states WHERE game_over);

COMMIT;
