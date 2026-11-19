-- Profile of raw.orders: one row per order, with status and the five lifecycle timestamps.
-- Run: python scripts/run_sql.py sql/profiling/profile_orders.sql
-- Analysis only, not part of the build.

-- Timestamps cast once here; TRY_CAST gives NULL for a value that does not parse.
CREATE TEMP VIEW orders_typed AS
SELECT
    order_id,
    customer_id,
    order_status,
    TRY_CAST(order_purchase_timestamp AS TIMESTAMP) AS purchase_ts,
    TRY_CAST(order_approved_at AS TIMESTAMP) AS approved_ts,
    TRY_CAST(order_delivered_carrier_date AS TIMESTAMP) AS carrier_ts,
    TRY_CAST(order_delivered_customer_date AS TIMESTAMP) AS delivered_ts,
    TRY_CAST(order_estimated_delivery_date AS TIMESTAMP) AS estimated_ts
FROM raw.orders;

-- Row count and key uniqueness. order_id is the key; customer_id is one per order in Olist.
SELECT
    count(*) AS rows,
    count(DISTINCT order_id) AS distinct_order_id,
    count(DISTINCT customer_id) AS distinct_customer_id
FROM raw.orders;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.orders;

-- Empty or blank strings per column (would not be NULL, but carry no value).
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.orders;

-- Non-NULL values that do not parse as a timestamp.
SELECT count_if(COLUMNS('order_.*(timestamp|_at|_date)') IS NOT NULL
                AND TRY_CAST(COLUMNS('order_.*(timestamp|_at|_date)') AS TIMESTAMP) IS NULL)
FROM raw.orders;

-- Status distribution, with how many orders in each status have each timestamp.
SELECT
    order_status,
    count(*) AS orders,
    count(approved_ts) AS with_approved,
    count(carrier_ts) AS with_carrier,
    count(delivered_ts) AS with_delivered
FROM orders_typed
GROUP BY order_status
ORDER BY orders DESC;

-- Date coverage of each timestamp.
SELECT
    min(purchase_ts) AS min_purchase, max(purchase_ts) AS max_purchase,
    min(delivered_ts) AS min_delivered, max(delivered_ts) AS max_delivered,
    min(estimated_ts) AS min_estimated, max(estimated_ts) AS max_estimated
FROM orders_typed;

-- Monthly orders by purchase month, to fix the reporting window (Review Focus 5).
SELECT
    strftime(purchase_ts, '%Y-%m') AS purchase_month,
    count(*) AS orders,
    count_if(order_status = 'delivered' AND delivered_ts IS NOT NULL) AS delivered,
    count_if(order_status = 'delivered' AND CAST(delivered_ts AS DATE) > CAST(estimated_ts AS DATE)) AS late
FROM orders_typed
GROUP BY purchase_month
ORDER BY purchase_month;

-- Timestamps out of order. Each count should be 0 in clean data.
SELECT
    count_if(approved_ts < purchase_ts) AS approved_before_purchase,
    count_if(carrier_ts < purchase_ts) AS carrier_before_purchase,
    count_if(carrier_ts < approved_ts) AS carrier_before_approved,
    count_if(delivered_ts < purchase_ts) AS delivered_before_purchase,
    count_if(delivered_ts < carrier_ts) AS delivered_before_carrier
FROM orders_typed;

-- The late rule compares dates because the estimate is assumed to be stored at midnight. Check it.
SELECT
    count(estimated_ts) AS with_estimate,
    count_if(estimated_ts <> date_trunc('day', estimated_ts)) AS estimate_not_at_midnight
FROM orders_typed;

-- Delivered population (Review Focus 3): status and delivery date must agree.
SELECT
    count_if(order_status = 'delivered' AND delivered_ts IS NOT NULL) AS delivered_with_date,
    count_if(order_status = 'delivered' AND delivered_ts IS NULL) AS delivered_without_date,
    count_if(order_status <> 'delivered' AND delivered_ts IS NOT NULL) AS other_status_with_date
FROM orders_typed;

-- Delay buckets for delivered orders, to confirm the bucket boundaries.
WITH delivered AS (
    SELECT CAST(delivered_ts AS DATE) - CAST(estimated_ts AS DATE) AS delay_days
    FROM orders_typed
    WHERE order_status = 'delivered' AND delivered_ts IS NOT NULL
)
SELECT
    CASE
        WHEN delay_days < 0 THEN 'Early'
        WHEN delay_days = 0 THEN 'On estimated day'
        WHEN delay_days <= 3 THEN '1-3 days late'
        WHEN delay_days <= 7 THEN '4-7 days late'
        WHEN delay_days <= 14 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_bucket,
    count(*) AS orders,
    round(100 * count(*) / sum(count(*)) OVER (), 2) AS pct_of_delivered
FROM delivered
GROUP BY delay_bucket
ORDER BY min(delay_days);

-- Same-day deliveries (Review Focus 4): how many orders a timestamp comparison would wrongly call late.
SELECT
    count_if(CAST(delivered_ts AS DATE) > CAST(estimated_ts AS DATE)) AS late_by_date,
    count_if(delivered_ts > estimated_ts) AS late_by_timestamp,
    late_by_timestamp - late_by_date AS same_day_counted_late
FROM orders_typed
WHERE order_status = 'delivered' AND delivered_ts IS NOT NULL;
