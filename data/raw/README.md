# Raw data

The CSV files are not committed. To rebuild the project, download them yourself:

1. Open https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce (needs a free Kaggle account) and click **Download**.
2. Unzip `archive.zip` (about 43 MB) so the nine CSV files sit directly in this folder.
3. From the repo root, run `python build.py`.

- **Source:** Brazilian E-Commerce Public Dataset by Olist, Kaggle
- **Downloaded:** 2026-11-18
- **License:** [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)

The files are kept exactly as downloaded. `tests/test_raw_load.py` checks these row counts after each build:

| File | Raw table | Rows |
|---|---|---:|
| `olist_orders_dataset.csv` | `raw.orders` | 99,441 |
| `olist_order_items_dataset.csv` | `raw.order_items` | 112,650 |
| `olist_customers_dataset.csv` | `raw.customers` | 99,441 |
| `olist_sellers_dataset.csv` | `raw.sellers` | 3,095 |
| `olist_products_dataset.csv` | `raw.products` | 32,951 |
| `olist_order_payments_dataset.csv` | `raw.payments` | 103,886 |
| `olist_order_reviews_dataset.csv` | `raw.reviews` | 99,224 |
| `olist_geolocation_dataset.csv` | `raw.geolocation` | 1,000,163 |
| `product_category_name_translation.csv` | `raw.category_translation` | 71 |

Known quirk in the source: `olist_products_dataset.csv` spells two columns `product_name_lenght` and `product_description_lenght`. The raw layer keeps the original names; staging renames them.
