-- Profile of raw.sellers: one row per seller, with location.
-- Run: python scripts/run_sql.py sql/profiling/profile_sellers.sql
-- Analysis only, not part of the build.

-- Row count and key uniqueness.
SELECT
    count(*) AS row_count,
    count(DISTINCT seller_id) AS distinct_seller_id
FROM raw.sellers;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.sellers;

-- Empty or blank strings per column.
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.sellers;

-- Zip prefix format: five digits, leading zeros kept.
SELECT
    count_if(NOT regexp_full_match(seller_zip_code_prefix, '\d{5}')) AS bad_zip_prefix,
    count_if(seller_zip_code_prefix LIKE '0%') AS zip_with_leading_zero
FROM raw.sellers;

-- City text: lowercase and trimmed, and free of digits or punctuation such as 'sao paulo / sp'?
SELECT
    count(DISTINCT seller_city) AS distinct_cities,
    count_if(seller_city <> lower(trim(seller_city))) AS city_not_lower_trimmed,
    count_if(regexp_matches(seller_city, '[0-9/@,]| - ')) AS city_with_digit_or_punctuation
FROM raw.sellers;

-- Seller states.
SELECT seller_state, count(*) AS sellers
FROM raw.sellers
GROUP BY seller_state
ORDER BY sellers DESC;

-- Delivered orders per seller (distinct orders), to confirm the 30-order ranking minimum.
-- An order with items from several sellers counts once for each of them.
WITH per_seller AS (
    SELECT i.seller_id, count(DISTINCT i.order_id) AS delivered_orders
    FROM raw.order_items AS i
    JOIN raw.orders AS o USING (order_id)
    WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY i.seller_id
)
SELECT
    count(*) AS sellers_with_delivered,
    count_if(delivered_orders >= 10) AS sellers_10_plus,
    count_if(delivered_orders >= 30) AS sellers_30_plus,
    count_if(delivered_orders >= 50) AS sellers_50_plus,
    count_if(delivered_orders >= 100) AS sellers_100_plus,
    median(delivered_orders) AS median_orders_per_seller,
    round(100 * sum(delivered_orders) FILTER (WHERE delivered_orders >= 30) / sum(delivered_orders), 1)
        AS pct_seller_orders_covered_by_30_plus
FROM per_seller;
