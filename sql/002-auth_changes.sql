BEGIN;
ALTER TABLE players DROP COLUMN token;

CREATE TABLE account_remember_keys (
  id integer PRIMARY KEY REFERENCES players
 ,key text NOT NULL
 ,deadline timestamp default CURRENT_TIMESTAMP + '365 days'::interval
);
COMMIT;
