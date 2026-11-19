# Data Profiling

*Session 2, 2026-11-19. Profiled on the raw layer (all columns VARCHAR, loaded unchanged from the Kaggle CSVs).*

Every number below comes from a query in [`sql/profiling/`](../sql/profiling/). The reference after each finding names the file and the comment above the query, for example *orders › Delay buckets*. To rerun a profile:

```
python build.py
python scripts/run_sql.py sql/profiling/profile_orders.sql
```

## 1. Decisions checked against the data

| Decision (from [requirements.md](requirements.md) and the plan) | Evidence | Result |
|---|---|---|
| Late = delivered date after estimated date, compared as dates | All 99,441 estimates are stored at midnight (*orders › The late rule compares dates*). A timestamp comparison would call 1,292 on-time orders late, which would inflate the late count by 20% (7,826 against 6,534; *orders › Same-day deliveries*). | Confirmed |
| Delivered order = status `delivered` **and** a delivery date | 8 orders have status `delivered` but no delivery date; 6 `canceled` orders have a delivery date (*orders › Delivered population*). Requiring both excludes all 14. | Confirmed |
| Delay buckets `Early`, `On estimated day`, `1-3`, `4-7`, `8-14`, `15+` days late | The late tail divides into four buckets of similar size, 1,384 to 1,870 orders each (1.4% to 1.9% of delivered orders). No late bucket is too thin to report (*orders › Delay buckets*). | Confirmed |
| Ranking minimum of 30 delivered orders | 627 of 2,970 sellers with a delivered order reach 30. Together they hold 83.5% of seller-level delivered orders. The median seller has 7. A minimum of 100 would keep only 210 sellers (*sellers › Delivered orders per seller*). All 27 states reach 30 over the whole period; the smallest is RR with 41, so short date ranges will drop the smallest states (*customers › Customer states*). | Confirmed |
| Reporting window | See section 2. | **2017-01 to 2018-08** |
| One review per order: the latest by answer time | 547 orders have 2 or 3 reviews, and 202 of them have different scores, so the rule changes results. No order has two reviews tied on the latest answer time, so the rule always picks exactly one (*reviews › For orders with several reviews*). | Confirmed |
| Seller and category measures count distinct orders | 1,278 orders (1.3% of orders with items) have items from more than one seller, at most 5; 3,236 (3.3%) contain more than one product (*order_items › Multi-seller and multi-product orders*). The limitation that a multi-seller order counts for each of its sellers affects about 1 order in 77. | Confirmed |
| Revenue = item `price`, not `payment_value` | For 99.7% of orders, the payments add up to price plus freight within one cent; 303 orders differ (*payments › Paid amount vs item price + freight*). `payment_value` therefore mostly equals merchandise plus freight. Interest or vouchers matter only for a small number of orders. The decision stands because `payment_value` includes freight and cannot be split by product or seller. | Confirmed, with the reason narrowed |
| Region = customer state; geolocation table not used | Geolocation has 1,000,163 rows for 19,015 zip prefixes (median 29 rows per prefix, up to 1,146). 261,831 rows are exact duplicates, 8 prefixes map to more than one state, 42 rows lie outside Brazil, and 278 customers and 7 sellers have no matching prefix (*geolocation*, *relationships › Zip prefixes*). The state column on customers is complete and clean. | Confirmed |

## 2. Reporting window

Monthly orders by purchase month (*orders › Monthly orders*):

- **2016:** 4 orders in September, 324 in October, none in November, 1 in December. The platform was still starting, and the November gap would break any trend line.
- **2017-01 to 2018-08:** 800 orders in the first month, then 1,780 to 7,544 a month.
- **2018-09 and 2018-10:** 16 and 4 orders, none delivered. The data was cut off.

The window is **January 2017 to August 2018 (20 full months)**. It keeps 99,092 of 99,441 orders (99.65%) and 96,203 of 96,470 delivered orders. The last month is complete. Its review coverage (99.7%) is the same as in earlier months, although reviews in the data end on 2018-08-31 (*relationships › Review coverage by purchase month*). Its share of undelivered orders (2.5%) is also in line with earlier months.

The late rate is not stable over time. Over the window it is 6.8% (6,531 of 96,203). It is below 5% in most months, and peaks at 12.4% in November 2017 (Black Friday), 14.1% in February 2018 and 19.0% in March 2018. A monthly trend is therefore worth showing.

## 3. Findings by table

**orders** (`profile_orders.sql`). 99,441 rows. `order_id` and `customer_id` are both unique. There are no blank strings, and every timestamp parses. Statuses: 96,478 `delivered`, 1,107 `shipped`, 625 `canceled`, 609 `unavailable`, and 622 in earlier stages (`invoiced`, `processing`, `created`, `approved`). NULLs: 160 approval, 1,783 carrier and 2,965 customer delivery timestamps, almost all on orders that never reached that stage. Out-of-order timestamps: none are approved or delivered before purchase, but 166 are handed to the carrier before purchase, 1,359 before approval, and 23 are delivered before the carrier hand-off. The carrier timestamp is not used by any KPI.

**order_items** (`profile_order_items.sql`). 112,650 rows. The key `(order_id, order_item_id)` is unique, and `order_item_id` runs 1..n in every order without gaps. Every price and freight value parses with at most two decimals. Price ranges from 0.85 to 6,735.00 BRL, with a median of 74.99; no price is zero. 383 items have zero freight. 88,863 orders (90%) have a single item, and the maximum is 21. Four items in three orders have a shipping limit in 2020, which is implausible. `shipping_limit_date` is not used.

**reviews** (`profile_reviews.sql`). 99,224 rows. `review_id` is **not** unique on its own (98,410 distinct). `(review_id, order_id)` is unique. 789 review ids are attached to 2 or 3 orders, so the same review is attached to each of them; each order keeps that score. All scores are integers from 1 to 5: 57.8% are 5 and 11.5% are 1. Comments are optional: 88% have no title and 59% no message. Review creation dates run from 2016-10-02 to 2018-08-31, and no answer comes before its creation date.

**customers** (`profile_customers.sql`). 99,441 rows, one per `customer_id`, which means one per order. They belong to 96,096 people (`customer_unique_id`). 2,997 people placed more than one order, up to 17. **39 people appear in more than one state**, so a person-level customer dimension cannot hold one state per person. Zip prefixes are all five digits, and 23,995 start with a zero, which the VARCHAR load keeps. City names are already lowercase and trimmed. There are 27 states.

**sellers** (`profile_sellers.sql`). 3,095 rows, and `seller_id` is unique. Sellers come from 23 states, and 1,849 of them (60%) are in SP. 23 city values are dirty, for example `sp / sp`, `04482255` or an e-mail address. Seller city is not used by the report.

**products** (`profile_products.sql`). 32,951 rows, and `product_id` is unique. There are 73 Portuguese categories. 610 products have no category, and they also lack name length, description length and photo count. 2 products have no dimensions, and 4 weigh 0 g. Two source columns are misspelled (`product_name_lenght`, `product_description_lenght`).

**category_translation** (`profile_category_translation.sql`). 71 rows with a one-to-one mapping, no NULLs, and all names in snake_case. The CSV starts with a UTF-8 byte order mark; DuckDB strips it, and the first column name reads correctly.

**payments** (`profile_payments.sql`). 103,886 rows. `(order_id, payment_sequential)` is unique, and 99,440 orders are covered. 74% of payments are credit card, followed by boleto, voucher and debit card. 3 payments have type `not_defined` and a value of 0.

**geolocation** (`profile_geolocation.sql`). See the region row in section 1.

**Relationships** (`profile_relationships.sql`). No orphan keys in any direction: every order has a customer, and every item has an order, a product and a seller. Every customer, product and seller is used. Every delivered order has items. 775 orders have no items, all `unavailable` (603), `canceled` (164) or in an early stage, so they carry no revenue. 95,824 of 96,470 delivered orders have a review, a **Review Coverage of 99.3%**. One delivered order has no payment. Two categories have no English translation: `pc_gamer` (9 items sold) and `portateis_cozinha_e_preparadores_de_alimentos` (15 items).

## 4. Implications for the next sessions

**Staging (Session 3)**
- Cast timestamps with `CAST`, not `TRY_CAST`, since every value parses. If a future file breaks this, the build should fail loudly instead of quietly producing NULLs.
- Money as `DECIMAL(10,2)`, never `DOUBLE`, so revenue reconciles to the cent.
- Reviews: keep one row per order, the latest by `review_answer_timestamp`. The key of the raw table is `(review_id, order_id)`.
- Customer state comes from the order's own `customer_id` row, not from the person. `fct_orders` carries the customer state of that order, and `dim_customer` (grain: `customer_unique_id`) holds no state.
- Products without a category, and the two untranslated categories, need an explicit English label. The rule is decided and documented in Session 3.
- Rename the misspelled product columns.

**Quality checks (Session 4)**
- The checks planned for "delivery and approval not before purchase" pass on today's data (0 rows each), so they can fail the build.
- Carrier timestamp anomalies (166 before purchase, 1,359 before approval, 23 delivered before carrier) are documented as known issues, not build failures. No KPI uses the carrier timestamp.
- Late flag only on delivered orders: the 14 status and date mismatches from section 1 are the rows this check guards against.
