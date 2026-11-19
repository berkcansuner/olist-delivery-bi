-- Relationships between the raw tables: orphan keys (a reference with no matching row) and
-- unmatched rows (a row nothing refers to). NOT EXISTS counts each row once, whatever the join fan-out.
-- Run: python scripts/run_sql.py sql/profiling/profile_relationships.sql
-- Analysis only, not part of the build.

-- Orphan keys: references that point to a missing row. Each count should be 0.
SELECT
    (SELECT count(*) FROM raw.orders AS o
     WHERE NOT EXISTS (SELECT 1 FROM raw.customers AS c WHERE c.customer_id = o.customer_id)) AS orders_without_customer,
    (SELECT count(*) FROM raw.order_items AS i
     WHERE NOT EXISTS (SELECT 1 FROM raw.orders AS o WHERE o.order_id = i.order_id)) AS items_without_order,
    (SELECT count(*) FROM raw.order_items AS i
     WHERE NOT EXISTS (SELECT 1 FROM raw.products AS p WHERE p.product_id = i.product_id)) AS items_without_product,
    (SELECT count(*) FROM raw.order_items AS i
     WHERE NOT EXISTS (SELECT 1 FROM raw.sellers AS s WHERE s.seller_id = i.seller_id)) AS items_without_seller,
    (SELECT count(*) FROM raw.reviews AS r
     WHERE NOT EXISTS (SELECT 1 FROM raw.orders AS o WHERE o.order_id = r.order_id)) AS reviews_without_order,
    (SELECT count(*) FROM raw.payments AS p
     WHERE NOT EXISTS (SELECT 1 FROM raw.orders AS o WHERE o.order_id = p.order_id)) AS payments_without_order;

-- Unmatched rows: dimension rows no order uses.
SELECT
    (SELECT count(*) FROM raw.customers AS c
     WHERE NOT EXISTS (SELECT 1 FROM raw.orders AS o WHERE o.customer_id = c.customer_id)) AS customers_without_order,
    (SELECT count(*) FROM raw.products AS p
     WHERE NOT EXISTS (SELECT 1 FROM raw.order_items AS i WHERE i.product_id = p.product_id)) AS products_never_sold,
    (SELECT count(*) FROM raw.sellers AS s
     WHERE NOT EXISTS (SELECT 1 FROM raw.order_items AS i WHERE i.seller_id = s.seller_id)) AS sellers_without_items;

-- Orders without items, payments or reviews, by status. Orders without items carry no revenue,
-- product or seller; delivered orders without a review lower Review Coverage.
SELECT
    o.order_status,
    count(*) AS orders,
    count_if(NOT EXISTS (SELECT 1 FROM raw.order_items AS i WHERE i.order_id = o.order_id)) AS without_items,
    count_if(NOT EXISTS (SELECT 1 FROM raw.payments AS p WHERE p.order_id = o.order_id)) AS without_payment,
    count_if(NOT EXISTS (SELECT 1 FROM raw.reviews AS r WHERE r.order_id = o.order_id)) AS without_review
FROM raw.orders AS o
GROUP BY o.order_status
ORDER BY orders DESC;

-- Review coverage of delivered orders (status delivered and a delivery date).
SELECT
    count(*) AS delivered_orders,
    count_if(EXISTS (SELECT 1 FROM raw.reviews AS r WHERE r.order_id = o.order_id)) AS with_review,
    round(100 * with_review / delivered_orders, 2) AS pct_with_review
FROM raw.orders AS o
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL;

-- Product categories without an English translation, with how much they sell.
SELECT
    p.product_category_name,
    count(DISTINCT p.product_id) AS products,
    count(i.order_id) AS items_sold
FROM raw.products AS p
LEFT JOIN raw.order_items AS i USING (product_id)
WHERE p.product_category_name IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM raw.category_translation AS t
                  WHERE t.product_category_name = p.product_category_name)
GROUP BY p.product_category_name;

-- Zip prefixes of customers and sellers that have no coordinates in geolocation.
SELECT
    (SELECT count(*) FROM raw.customers AS c
     WHERE NOT EXISTS (SELECT 1 FROM raw.geolocation AS g
                       WHERE g.geolocation_zip_code_prefix = c.customer_zip_code_prefix)) AS customers_without_geo,
    (SELECT count(*) FROM raw.sellers AS s
     WHERE NOT EXISTS (SELECT 1 FROM raw.geolocation AS g
                       WHERE g.geolocation_zip_code_prefix = s.seller_zip_code_prefix)) AS sellers_without_geo;
