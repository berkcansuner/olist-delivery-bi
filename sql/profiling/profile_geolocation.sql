-- Profile of raw.geolocation: coordinates per zip code prefix, with city and state.
-- Not used by the model (region is customer state); this profile shows why.
-- Run: python scripts/run_sql.py sql/profiling/profile_geolocation.sql
-- Analysis only, not part of the build.

-- Row count, zip prefixes and exact duplicate rows.
SELECT
    count(*) AS row_count,
    count(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes,
    count(*) - (SELECT count(*) FROM (SELECT DISTINCT * FROM raw.geolocation)) AS exact_duplicate_rows,
    count(DISTINCT geolocation_state) AS distinct_states
FROM raw.geolocation;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.geolocation;

-- Rows per zip prefix: one prefix has many coordinates.
SELECT
    min(n) AS min_rows_per_prefix,
    median(n) AS median_rows_per_prefix,
    max(n) AS max_rows_per_prefix
FROM (SELECT count(*) AS n FROM raw.geolocation GROUP BY geolocation_zip_code_prefix);

-- Zip prefixes that map to more than one state.
SELECT count(*) AS prefixes_in_several_states
FROM (
    SELECT geolocation_zip_code_prefix
    FROM raw.geolocation
    GROUP BY geolocation_zip_code_prefix
    HAVING count(DISTINCT geolocation_state) > 1
);

-- Coordinates outside Brazil's bounding box (about lat -34 to 6, lng -74 to -34).
SELECT count(*) AS rows_outside_brazil
FROM raw.geolocation
WHERE NOT (CAST(geolocation_lat AS DOUBLE) BETWEEN -34 AND 6
           AND CAST(geolocation_lng AS DOUBLE) BETWEEN -74 AND -34);
