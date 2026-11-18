-- Raw layer: the nine Olist CSVs loaded unchanged.
-- Every column is read as VARCHAR (all_varchar = true) so that no type is guessed here.
-- Types, renames and cleaning happen explicitly in the staging layer.
-- Paths are relative to the repo root (build.py runs from there).

CREATE SCHEMA raw;

CREATE TABLE raw.orders AS
SELECT * FROM read_csv('data/raw/olist_orders_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.order_items AS
SELECT * FROM read_csv('data/raw/olist_order_items_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.customers AS
SELECT * FROM read_csv('data/raw/olist_customers_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.sellers AS
SELECT * FROM read_csv('data/raw/olist_sellers_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.products AS
SELECT * FROM read_csv('data/raw/olist_products_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.payments AS
SELECT * FROM read_csv('data/raw/olist_order_payments_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.reviews AS
SELECT * FROM read_csv('data/raw/olist_order_reviews_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.geolocation AS
SELECT * FROM read_csv('data/raw/olist_geolocation_dataset.csv', header = true, all_varchar = true);

CREATE TABLE raw.category_translation AS
SELECT * FROM read_csv('data/raw/product_category_name_translation.csv', header = true, all_varchar = true);
