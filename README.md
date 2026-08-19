# Sparkify Postgres ETL | Star Schema Data Modeling

An ETL pipeline that extracts user activity and song metadata from JSON logs, transforms it into a dimensional model, and loads it into a PostgreSQL star schema built for analytical querying.

- **Stack:** Python · PostgreSQL · psycopg2 · pandas
- **Data:** Song metadata and simulated user activity logs from a music streaming service

---

## Overview

Sparkify, a music streaming startup, collects listening activity as JSON files. In that form the data cannot be queried or joined, which makes analysis impractical. This project builds the pipeline that turns those files into a relational database the analytics team can actually use.

The target design is a star schema: one fact table recording song plays, surrounded by four dimension tables holding descriptive context. This structure keeps analytical queries simple and fast, since answering a question like "which hours of the day see the most paid-tier listening" requires one join rather than several.

## Schema

```mermaid
erDiagram
    songplays {
        SERIAL songplay_id PK
        TIMESTAMP start_time FK
        INT user_id FK
        VARCHAR level
        VARCHAR song_id FK
        VARCHAR artist_id FK
        INT session_id
        VARCHAR location
        VARCHAR user_agent
    }
    users {
        INT user_id PK
        VARCHAR first_name
        VARCHAR last_name
        VARCHAR gender
        VARCHAR level
    }
    songs {
        VARCHAR song_id PK
        VARCHAR title
        VARCHAR artist_id FK
        INT year
        NUMERIC duration
    }
    artists {
        VARCHAR artist_id PK
        VARCHAR name
        VARCHAR location
        FLOAT latitude
        FLOAT longitude
    }
    time {
        TIMESTAMP start_time PK
        INT hour
        INT day
        INT week
        INT month
        INT year
        INT weekday
    }
    songplays }o--|| users : "user_id"
    songplays }o--o| songs : "song_id"
    songplays }o--o| artists : "artist_id"
    songplays }o--|| time : "start_time"
    songs }o--|| artists : "artist_id"
```

`songplays` is the fact table. Each row is one song play event, holding the measurable activity and foreign keys out to the dimensions. The four dimension tables are denormalized on purpose: a star schema trades some redundancy for query simplicity, which is the right trade when the workload is analytical rather than transactional.

## Design Decisions

**Users are upserted, not inserted.** A listener can move between the free and paid tiers, so a plain insert would either fail on the primary key or silently keep a stale subscription level. The user insert uses `ON CONFLICT (user_id) DO UPDATE` so the record reflects the most recent state:

```sql
INSERT INTO users (user_id, first_name, last_name, gender, level)
VALUES (%s, %s, %s, %s, %s)
ON CONFLICT (user_id) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name  = EXCLUDED.last_name,
    gender     = EXCLUDED.gender,
    level      = EXCLUDED.level
```

**Other tables use `ON CONFLICT DO NOTHING`**, since song, artist, and time records are immutable once written. Re-running the pipeline over the same files is therefore safe and does not duplicate rows.

**Song and artist IDs on the fact table are nullable.** Matching a play event back to the song catalog requires an exact match on title, artist name, and duration, and the catalog subset does not contain every song that appears in the logs. Rather than dropping unmatched plays, the pipeline records them with null identifiers, which preserves the event and makes the coverage gap measurable instead of invisible.

**Timestamps are decomposed into a time dimension** at load rather than being derived at query time, so hour-of-day and day-of-week analysis does not require date functions in every query.

**`NOT NULL` constraints are applied selectively** — on fields the schema genuinely depends on, and not on optional metadata like artist latitude and longitude, which is missing for a meaningful share of records.

## Pipeline

| Stage | Script | What it does |
|---|---|---|
| Schema setup | `create_tables.py` | Drops and recreates the database and all five tables |
| Song ingest | `etl.py` → `process_song_file` | Reads song JSON, populates `songs` and `artists` |
| Log ingest | `etl.py` → `process_log_file` | Filters to `NextSong` events, decomposes timestamps, populates `time`, `users`, and `songplays` |
| Verification | `test.ipynb` | Confirms tables are populated and constraints hold |

`etl.ipynb` is the development notebook where the transformation logic was worked out one file at a time before being generalized into `etl.py`.

## Setup and Usage

Requires a running PostgreSQL instance and Python 3 with `pandas` and `psycopg2`.

```bash
git clone https://github.com/AliKatMcKin/sparkify-postgres-etl.git
cd sparkify-postgres-etl
pip install pandas psycopg2-binary
```

```bash
python create_tables.py   # build the schema
python etl.py             # run the pipeline
```

Then open `test.ipynb` to verify the load.

## Repository Structure

```
├── create_tables.py   # Database and table creation
├── etl.py             # ETL pipeline
├── sql_queries.py     # All DDL and DML statements
├── etl.ipynb          # Development notebook
├── test.ipynb         # Load verification
└── data/
    ├── song_data/     # Song metadata JSON
    └── log_data/      # User activity log JSON
```

## Notes and Limitations

- **Connection parameters are hardcoded** to the local development defaults used during the course. In a production deployment these belong in environment variables or a configuration file rather than in source.
- **Inserts are row-by-row.** This is readable and correct at this data volume. At production scale, `execute_batch` or `COPY` would be substantially faster.
- **Song matching is exact-match on three fields**, so the `song_id` and `artist_id` coverage on the fact table is limited by the size of the song catalog subset.
- The activity logs are simulated rather than real user data.

## Attribution

Project scenario, starter structure, and sample data were provided as part of the Udacity/WGU Data Wrangling curriculum. The schema design, SQL statements, transformation logic, and pipeline implementation are my own work.

*Completed for D497 Data Wrangling, BS in Data Analytics, Western Governors University. Author: Alissa McKinney.*
