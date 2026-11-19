-- Profile of raw.order_items: one row per item in an order, with product, seller, price and freight.
-- Run: python scripts/run_sql.py sql/profiling/profile_order_items.sql
-- Analysis only, not part of the build.

-- Row count and key uniqueness. The key is (order_id, order_item_id).
SELECT
    count(*) AS row_count,
    count(DISTINCT (order_id, order_item_id)) AS distinct_key,
    count(DISTINCT order_id) AS distinct_orders,
    count(DISTINCT product_id) AS distinct_products,
    count(DISTINCT seller_id) AS distinct_sellers
FROM raw.order_items;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.order_items;

-- Empty or blank strings per column.
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.order_items;

-- Values that do not parse as their intended type. Money must have at most two decimals for DECIMAL(10,2).
SELECT
    count_if(TRY_CAST(order_item_id AS INTEGER) IS NULL) AS bad_item_id,
    count_if(TRY_CAST(shipping_limit_date AS TIMESTAMP) IS NULL) AS bad_shipping_limit,
    count_if(NOT regexp_full_match(price, '\d+(\.\d{1,2})?')) AS bad_price,
    count_if(NOT regexp_full_match(freight_value, '\d+(\.\d{1,2})?')) AS bad_freight
FROM raw.order_items;

-- Ranges of price and freight, and how many are zero.
SELECT
    min(CAST(price AS DECIMAL(10, 2))) AS min_price,
    median(CAST(price AS DECIMAL(10, 2))) AS median_price,
    max(CAST(price AS DECIMAL(10, 2))) AS max_price,
    count_if(CAST(price AS DECIMAL(10, 2)) = 0) AS zero_price,
    min(CAST(freight_value AS DECIMAL(10, 2))) AS min_freight,
    median(CAST(freight_value AS DECIMAL(10, 2))) AS median_freight,
    max(CAST(freight_value AS DECIMAL(10, 2))) AS max_freight,
    count_if(CAST(freight_value AS DECIMAL(10, 2)) = 0) AS zero_freight
FROM raw.order_items;

-- Range of the shipping limit date.
SELECT
    min(CAST(shipping_limit_date AS TIMESTAMP)) AS min_shipping_limit,
    max(CAST(shipping_limit_date AS TIMESTAMP)) AS max_shipping_limit
FROM raw.order_items;

-- Shipping limits after the last purchase in the data (2018-10-17) look implausible. How many?
SELECT
    count(*) AS items_with_late_limit,
    count(DISTINCT order_id) AS orders_with_late_limit
FROM raw.order_items
WHERE CAST(shipping_limit_date AS TIMESTAMP) > TIMESTAMP '2018-10-18';

-- order_item_id should run 1..n within each order with no gaps.
SELECT count(*) AS orders_with_gaps
FROM (
    SELECT order_id
    FROM raw.order_items
    GROUP BY order_id
    HAVING max(CAST(order_item_id AS INTEGER)) <> count(*)
);

-- Items per order.
SELECT items_per_order, count(*) AS orders
FROM (SELECT order_id, count(*) AS items_per_order FROM raw.order_items GROUP BY order_id)
GROUP BY items_per_order
ORDER BY items_per_order;

-- Multi-seller and multi-product orders (Review Focus 2).
WITH per_order AS (
    SELECT
        order_id,
        count(DISTINCT seller_id) AS sellers,
        count(DISTINCT product_id) AS products
    FROM raw.order_items
    GROUP BY order_id
)
SELECT
    count(*) AS orders_with_items,
    count_if(sellers > 1) AS multi_seller_orders,
    round(100 * count_if(sellers > 1) / count(*), 2) AS pct_multi_seller,
    count_if(products > 1) AS multi_product_orders,
    round(100 * count_if(products > 1) / count(*), 2) AS pct_multi_product,
    max(sellers) AS max_sellers_in_one_order
FROM per_order;
