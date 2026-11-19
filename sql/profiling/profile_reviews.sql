-- Profile of raw.reviews: customer reviews (score 1-5, optional comment) linked to orders.
-- Run: python scripts/run_sql.py sql/profiling/profile_reviews.sql
-- Analysis only, not part of the build.

-- Row count and key candidates. Is review_id unique on its own, or only together with order_id?
SELECT
    count(*) AS row_count,
    count(DISTINCT review_id) AS distinct_review_id,
    count(DISTINCT order_id) AS distinct_order_id,
    count(DISTINCT (review_id, order_id)) AS distinct_review_order_pair
FROM raw.reviews;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.reviews;

-- Empty or blank strings per column.
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.reviews;

-- Values that do not parse as their intended type.
SELECT
    count_if(TRY_CAST(review_score AS INTEGER) IS NULL) AS bad_score,
    count_if(TRY_CAST(review_creation_date AS TIMESTAMP) IS NULL) AS bad_creation_date,
    count_if(TRY_CAST(review_answer_timestamp AS TIMESTAMP) IS NULL) AS bad_answer_ts
FROM raw.reviews;

-- Score distribution. Scores must be 1-5.
SELECT
    review_score,
    count(*) AS reviews,
    round(100 * count(*) / sum(count(*)) OVER (), 2) AS pct
FROM raw.reviews
GROUP BY review_score
ORDER BY review_score;

-- Date ranges, and answers recorded before the review was created.
SELECT
    min(CAST(review_creation_date AS TIMESTAMP)) AS min_creation,
    max(CAST(review_creation_date AS TIMESTAMP)) AS max_creation,
    min(CAST(review_answer_timestamp AS TIMESTAMP)) AS min_answer,
    max(CAST(review_answer_timestamp AS TIMESTAMP)) AS max_answer,
    count_if(CAST(review_answer_timestamp AS TIMESTAMP) < CAST(review_creation_date AS TIMESTAMP)) AS answer_before_creation
FROM raw.reviews;

-- Reviews per order (Review Focus 1). Orders with no review at all are counted in profile_relationships.sql.
SELECT reviews_per_order, count(*) AS orders
FROM (SELECT order_id, count(*) AS reviews_per_order FROM raw.reviews GROUP BY order_id)
GROUP BY reviews_per_order
ORDER BY reviews_per_order;

-- Orders per review_id: one review shared by several orders (Review Focus 1).
SELECT orders_per_review, count(*) AS review_ids
FROM (SELECT review_id, count(DISTINCT order_id) AS orders_per_review FROM raw.reviews GROUP BY review_id)
GROUP BY orders_per_review
ORDER BY orders_per_review;

-- For orders with several reviews: do the scores differ, and does "latest by answer time" pick one review?
WITH multi AS (
    SELECT
        order_id,
        count(DISTINCT review_score) AS distinct_scores,
        count_if(CAST(review_answer_timestamp AS TIMESTAMP) = max_answer) AS reviews_at_latest_answer
    FROM (
        SELECT *, max(CAST(review_answer_timestamp AS TIMESTAMP)) OVER (PARTITION BY order_id) AS max_answer
        FROM raw.reviews
    )
    GROUP BY order_id
    HAVING count(*) > 1
)
SELECT
    count(*) AS orders_with_several_reviews,
    count_if(distinct_scores > 1) AS with_different_scores,
    count_if(reviews_at_latest_answer > 1) AS tied_on_latest_answer
FROM multi;
