-- Sparkify Database Schema
-- Star schema: songplays fact table with four dimension tables.
-- These statements are executed programmatically from sql_queries.py.
-- This file is the reference copy of the data definition language.

-- ============================================================
-- FACT TABLE
-- ============================================================

-- One row per song play event.
-- song_id and artist_id are nullable: catalog matching requires an exact
-- match on title, artist name, and duration, and the catalog subset does
-- not cover every song in the logs. Unmatched plays are retained rather
-- than dropped so the coverage gap stays measurable.
CREATE TABLE IF NOT EXISTS songplays (
    songplay_id SERIAL PRIMARY KEY,
    start_time  TIMESTAMP NOT NULL,
    user_id     INT NOT NULL,
    level       VARCHAR NOT NULL,
    song_id     VARCHAR,
    artist_id   VARCHAR,
    session_id  INT,
    location    VARCHAR,
    user_agent  VARCHAR
);

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS users (
    user_id    INT PRIMARY KEY,
    first_name VARCHAR NOT NULL,
    last_name  VARCHAR NOT NULL,
    gender     VARCHAR,
    level      VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS songs (
    song_id   VARCHAR PRIMARY KEY,
    title     VARCHAR NOT NULL,
    artist_id VARCHAR NOT NULL,
    year      INT NOT NULL,
    duration  NUMERIC NOT NULL
);

-- latitude and longitude are nullable: absent for a meaningful share
-- of records in the source catalog.
CREATE TABLE IF NOT EXISTS artists (
    artist_id VARCHAR PRIMARY KEY,
    name      VARCHAR NOT NULL,
    location  VARCHAR,
    latitude  FLOAT,
    longitude FLOAT
);

-- Timestamps are decomposed at load so that hour-of-day and day-of-week
-- analysis requires no date functions at query time.
CREATE TABLE IF NOT EXISTS time (
    start_time TIMESTAMP PRIMARY KEY,
    hour       INT NOT NULL,
    day        INT NOT NULL,
    week       INT NOT NULL,
    month      INT NOT NULL,
    year       INT NOT NULL,
    weekday    INT NOT NULL
);

-- ============================================================
-- REFERENCE: CATALOG LOOKUP
-- ============================================================

-- Resolves a play event to catalog identifiers during log ingest.
SELECT songs.song_id, artists.artist_id
FROM songs
JOIN artists ON songs.artist_id = artists.artist_id
WHERE songs.title = %s
  AND artists.name = %s
  AND songs.duration = %s;
