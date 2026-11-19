-- Profile of raw.category_translation: Portuguese category name to English.
-- Categories in products without a translation are counted in profile_relationships.sql.
-- Run: python scripts/run_sql.py sql/profiling/profile_category_translation.sql
-- Analysis only, not part of the build.

-- Row count and key uniqueness. Both names should be unique (one-to-one mapping).
SELECT
    count(*) AS row_count,
    count(DISTINCT product_category_name) AS distinct_portuguese,
    count(DISTINCT product_category_name_english) AS distinct_english
FROM raw.category_translation;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.category_translation;

-- Empty or blank strings per column.
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.category_translation;

-- Format: lowercase snake_case names, as the rest of the data uses.
SELECT
    count_if(NOT regexp_full_match(product_category_name, '[a-z0-9_]+')) AS portuguese_not_snake_case,
    count_if(NOT regexp_full_match(product_category_name_english, '[a-z0-9_]+')) AS english_not_snake_case
FROM raw.category_translation;
