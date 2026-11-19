-- Profile of raw.payments: one row per payment of an order (an order can be paid in several parts).
-- Payment analysis is out of scope; this profile checks the table and shows why Revenue uses item price.
-- Run: python scripts/run_sql.py sql/profiling/profile_payments.sql
-- Analysis only, not part of the build.

-- Row count and key uniqueness. The key is (order_id, payment_sequential).
SELECT
    count(*) AS row_count,
    count(DISTINCT (order_id, payment_sequential)) AS distinct_key,
    count(DISTINCT order_id) AS distinct_orders
FROM raw.payments;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.payments;

-- Values that do not parse as their intended type.
SELECT
    count_if(TRY_CAST(payment_sequential AS INTEGER) IS NULL) AS bad_sequential,
    count_if(TRY_CAST(payment_installments AS INTEGER) IS NULL) AS bad_installments,
    count_if(NOT regexp_full_match(payment_value, '\d+(\.\d{1,2})?')) AS bad_value
FROM raw.payments;

-- Payment types.
SELECT payment_type, count(*) AS payments, sum(CAST(payment_value AS DECIMAL(12, 2))) AS value
FROM raw.payments
GROUP BY payment_type
ORDER BY payments DESC;

-- Paid amount vs item price + freight, per order. A difference means payment_value
-- cannot stand in for item revenue (instalment interest, vouchers, rounding).
WITH paid AS (
    SELECT order_id, sum(CAST(payment_value AS DECIMAL(12, 2))) AS paid
    FROM raw.payments
    GROUP BY order_id
),
items AS (
    SELECT order_id, sum(CAST(price AS DECIMAL(12, 2)) + CAST(freight_value AS DECIMAL(12, 2))) AS price_plus_freight
    FROM raw.order_items
    GROUP BY order_id
)
SELECT
    count(*) AS orders_in_both,
    count_if(abs(paid - price_plus_freight) <= 0.01) AS match_within_1_cent,
    count_if(paid - price_plus_freight > 0.01) AS paid_more,
    count_if(price_plus_freight - paid > 0.01) AS paid_less
FROM paid
JOIN items USING (order_id);
