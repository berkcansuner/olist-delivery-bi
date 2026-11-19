-- Profile of raw.products: one row per product, with Portuguese category name and physical attributes.
-- Note the misspelled source columns (product_name_lenght, product_description_lenght); staging renames them.
-- Run: python scripts/run_sql.py sql/profiling/profile_products.sql
-- Analysis only, not part of the build.

-- Row count and key uniqueness.
SELECT
    count(*) AS row_count,
    count(DISTINCT product_id) AS distinct_product_id,
    count(DISTINCT product_category_name) AS distinct_categories
FROM raw.products;

-- NULLs per column.
SELECT count(*) - count(COLUMNS(*)) FROM raw.products;

-- Empty or blank strings per column.
SELECT count_if(trim(COLUMNS(*)) = '') FROM raw.products;

-- Numeric columns that do not parse as integers.
SELECT count_if(COLUMNS('product_(name|description|photos|weight|length|height|width).*') IS NOT NULL
                AND TRY_CAST(COLUMNS('product_(name|description|photos|weight|length|height|width).*') AS INTEGER) IS NULL)
FROM raw.products;

-- Ranges of the physical attributes, and zero weights.
SELECT
    min(CAST(product_weight_g AS INTEGER)) AS min_weight_g,
    max(CAST(product_weight_g AS INTEGER)) AS max_weight_g,
    count_if(CAST(product_weight_g AS INTEGER) = 0) AS zero_weight,
    min(CAST(product_photos_qty AS INTEGER)) AS min_photos,
    max(CAST(product_photos_qty AS INTEGER)) AS max_photos
FROM raw.products;

-- Products without a category: do they also miss the other attributes?
SELECT
    count(*) AS products_without_category,
    count(product_weight_g) AS of_which_with_weight,
    count(product_photos_qty) AS of_which_with_photos
FROM raw.products
WHERE product_category_name IS NULL;

-- Categories by number of products (top 10).
SELECT product_category_name, count(*) AS products
FROM raw.products
GROUP BY product_category_name
ORDER BY products DESC
LIMIT 10;
