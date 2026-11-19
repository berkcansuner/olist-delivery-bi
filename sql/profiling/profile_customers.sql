-- Profile of raw.customers: one row per customer_id. Olist issues a new customer_id for every order;
-- customer_unique_id identifies the person.
-- Run: python scripts/run_sql.py sql/profiling/profile_customers.sql
-- Analysis only, not part of the build.

-- Row count and key uniqueness.
SELECT
    count(*) AS row_count,
    count(DISTINCT customer_id) AS distinct_customer_id,
    count(DISTINCT customer_unique_id) AS distinct_customer_unique_id
FROM raw.customers;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.customers;

-- Empty or blank strings per column.
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.customers;

-- Repeat customers: people (customer_unique_id) with several customer_ids, and how many of them
-- appear in more than one state.
WITH per_person AS (
    SELECT
        customer_unique_id,
        count(*) AS customer_ids,
        count(DISTINCT customer_state) AS states
    FROM raw.customers
    GROUP BY customer_unique_id
)
SELECT
    count_if(customer_ids > 1) AS people_with_several_ids,
    max(customer_ids) AS max_ids_per_person,
    count_if(states > 1) AS people_in_several_states
FROM per_person;

-- Zip prefix format: five digits, leading zeros kept.
SELECT
    count_if(NOT regexp_full_match(customer_zip_code_prefix, '\d{5}')) AS bad_zip_prefix,
    count_if(customer_zip_code_prefix LIKE '0%') AS zip_with_leading_zero
FROM raw.customers;

-- City text: already lowercase and trimmed?
SELECT
    count(DISTINCT customer_city) AS distinct_cities,
    count_if(customer_city <> lower(trim(customer_city))) AS city_not_lower_trimmed
FROM raw.customers;

-- Customer states, with delivered orders per state (for the 30-order ranking minimum).
SELECT
    c.customer_state,
    count(*) AS customer_ids,
    count_if(o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL) AS delivered_orders
FROM raw.customers AS c
LEFT JOIN raw.orders AS o USING (customer_id)
GROUP BY c.customer_state
ORDER BY delivered_orders DESC;
