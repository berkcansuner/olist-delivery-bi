# Olist Delivery BI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public, reproducible BI project on the Olist dataset that answers "How much do late deliveries hurt customer review scores, and which sellers and regions drive the problem?", using SQL in DuckDB for the data work and Power BI for the report.

**Architecture:** Raw CSVs are loaded unchanged into DuckDB, then SQL builds a staging layer (typed, cleaned, renamed) and a marts layer (star schema). Quality checks run as part of the build and stop it if anything fails. The marts are exported to Parquet, and Power BI Desktop imports the Parquet files. One command (`python build.py`) rebuilds everything from the raw CSVs.

**Tech Stack:** Python 3.12 (thin runner only), DuckDB 2.0.0 (Python package), pytest 9.2.0, Power BI Desktop (Windows), Git + GitHub.

**Spec:** `docs/specs/2026-11-18-olist-powerbi-design.md`

## Global Constraints

- Free tools only, runs on a Windows laptop. No live database, cloud warehouse, ML, forecasting, web app or custom theme work.
- Code, SQL, docs, README and comments in English.
- Late delivery and low review scores are reported as *associated*, never as cause and effect. Confounders (category, distance, seller) are named where relevant.
- No transformation or DAX measure that cannot be explained in plain language.
- Personal project: never framed as work experience.
- Raw CSVs stay unchanged under `data/raw/` and are never committed. Source URL and download date are recorded.
- Data credit: "Brazilian E-Commerce Public Dataset by Olist", CC BY-NC-SA 4.0. The license note goes in the README.
- Git: small commits, one per meaningful unit. Work on `main` only. No backdating, squashing or history rewrites. Berk approves every push after seeing the commit list.
- Pacing: one work package per session, each on a different day. Stop when the package is done.
- The first push contains only the README skeleton, the design doc and the folder structure.
- Berk builds the `.pbix` himself. Claude writes step-by-step Turkish instructions for each page and reviews the screenshots.

## Decisions (made now, confirmed or revised with profiling evidence)

| Topic | Decision | Rejected alternatives |
|---|---|---|
| Runner | `python build.py` runs the SQL files in layer order with the `duckdb` Python package | DuckDB CLI `.read` (extra install, no fail-loudly logic). Makefile (no `make` on Windows) |
| Raw typing | Raw layer read with `all_varchar=true`. All typing is explicit in staging | Auto-detected types: hidden decisions, e.g. zip prefix `01001` would become integer `1001` |
| Fact grain | Two facts at their natural grain: `fct_order_items` (one row per order item: sales, freight, product, seller) and `fct_orders` (one row per order: delivery dates, delay, lateness, review score). Order-level `is_late`, `delay_bucket` and `review_score` are also carried on `fct_order_items`, so seller-level measures can count **distinct orders** | Item grain only: an order with 4 items would count its review 4 times. Order grain only: loses product and seller, and an order can have several of each |
| Late | Delivered orders only (`order_status = 'delivered'` and delivered date present). Late = `CAST(delivered_customer_ts AS DATE) > CAST(estimated_delivery_ts AS DATE)` | Timestamp comparison: the estimate is stored at midnight, so a delivery at 15:00 on the promised day would wrongly count as late. Seller hand-off vs `shipping_limit_date`: measures seller handling, not what the customer experienced. A fixed "more than N days" rule ignores the promise made to the customer |
| Delay buckets | `delay_days = delivered_date - estimated_date`. Buckets: `Early`, `On estimated day` (0), `1-3 days late`, `4-7 days late`, `8-14 days late`, `15+ days late` | Finer buckets leave too few orders in the late tail |
| Seller ranking minimum | At least 30 delivered orders in the selected period | No minimum: a seller with 1 late order out of 2 shows a 50% late rate. 100: leaves too few sellers to rank |
| Region | Customer state (where the order is delivered to), grouped into Brazil's five macro-regions. `dim_geography` has state grain (27 rows). Seller state stays an attribute on `dim_seller` | Zip-prefix geography from the geolocation table: about 1M rows with many coordinates per prefix, and it is only needed for maps. A role-playing geography dimension for customer and seller: more relationships than the question needs |
| Sales measure | `Revenue` = sum of item `price`, excluding freight, for orders not `canceled` or `unavailable`. Documented as merchandise value, not Olist's own income (Olist earns a commission) | `payment_value`: includes freight and instalment interest, and cannot be split by product or seller |
| Review per order | One review per order: the latest by `review_answer_timestamp`. Orders without a review keep a null score and are excluded from average-score measures, with the count reported | Averaging multiple reviews per order: unclear meaning. Dropping orders without a review from the delivery measures: would bias the late rate |
| Keys | Olist's natural ids (hash strings) as keys | Integer surrogate keys: the Kimball standard, but they add no value at about 100k rows and make the mapping harder to read |
| Date table | Built in Power Query (M code saved as `powerbi/date_table.m`). Facts carry plain `DATE` columns | A SQL `dim_date`: works, but the spec asks for Power Query to stay visible |

## Folder Layout

```
README.md, LICENSE, .gitignore, requirements.txt, build.py
data/raw/          CSVs (ignored) + README.md (source, download date)
data/marts/        Parquet output (ignored, rebuilt by build.py)
sql/01_raw/        load_raw.sql
sql/02_staging/    stg_<table>.sql
sql/03_marts/      dim_<name>.sql, fct_<name>.sql
sql/04_quality/    dq_<check>.sql (each returns violating rows, so an empty result means pass)
sql/profiling/     profile_<table>.sql (analysis only, not part of the build)
scripts/run_sql.py prints the result of every statement in a .sql file
tests/             pytest
powerbi/           olist_delivery.pbix, measures.dax, date_table.m, screenshots/
docs/              specs/, plans/, requirements.md, profiling.md, data_model.md,
                   source_to_target.md, data_quality.md
```

`data/olist.duckdb` is ignored and rebuilt from scratch on every build.

## Review Focus

1. **Orders with several reviews, or one review shared by several orders.** The average score must count each order once. Test: `dq_fct_orders_one_row_per_order` (Session 4) and a profiling query that counts both cases (Session 2).
2. **Multi-item and multi-seller orders.** Seller and category review averages must be computed over distinct orders. A multi-seller order's lateness counts for each of its sellers; this is a documented limitation. Test: a profiling query for the share of multi-seller orders (Session 2), plus a DAX check during the build of the seller page: `Avg Review Score` on a one-seller filter equals the SQL average over that seller's distinct orders.
3. **Non-delivered orders leaking into the late rate.** Canceled orders, shipped-but-not-delivered orders and delivered orders without a delivery date must not be counted. Test: `dq_late_flag_only_on_delivered` (Session 4).
4. **Same-day deliveries counted as late** because of the timestamp comparison. Test: `dq_late_flag_matches_date_rule` recomputes the flag at date level (Session 4).
5. **Incomplete months at the start and end** (sparse 2016 data, few orders after August 2018) distorting trend lines. Test: a monthly order count in profiling (Session 2). The trimmed reporting window is stated in `docs/requirements.md` and applied in the report.

---

## Session 1: Repo setup, requirements, raw load (today)

### Task 1: Repo skeleton and first push

**Files:** Create `README.md` (skeleton), `.gitignore`, `LICENSE` (MIT, same as Hillstrom), `.gitkeep` in each empty folder of the layout above. Already present: `docs/specs/2026-11-18-olist-powerbi-design.md`.

- [ ] **Step 1:** `.gitignore` covers `.venv/`, `__pycache__/`, `.pytest_cache/`, `data/raw/*.csv`, `data/raw/*.zip`, `data/marts/`, `data/*.duckdb*`.
- [ ] **Step 2:** README skeleton: title, the business question, status "Work in progress", planned sections (Finding, Report, Data model, How to rebuild, Docs) as headings with no content, and the data credit and license note.
- [ ] **Step 3:** Verify: `git status --ignored` shows nothing unexpected.
- [ ] **Step 4:** Commits, one per unit: `Add project design document`, `Add folder structure and .gitignore`, `Add MIT license`, `Add README skeleton`.
- [ ] **Step 5:** Ask Berk for approval, then create the public repo `berkcansuner/olist-delivery-bi` (description: "End-to-end BI project on Olist e-commerce data: SQL in DuckDB, star schema, data quality checks, Power BI report").
- [ ] **Step 6:** Show `git log --oneline`. After Berk approves, `git remote add origin ...` and `git push -u origin main`. Verify that `git status` reports "up to date with 'origin/main'".

### Task 2: Requirements doc

**Files:** Create `docs/requirements.md`.

- [ ] **Step 1:** Write the doc (1–2 pages) with these sections. Stakeholder: a hypothetical Head of Customer Experience at Olist, stated as hypothetical. Business questions: the main one and the commercial context. KPI table: name, exact definition, filter, and grain at which it is computed, for `Revenue`, `Orders`, `Average Order Value`, `Delivered Orders`, `Late Rate`, `Avg Delay Days (late orders)`, `Avg Review Score`, `Low Review Rate` (score 1–2), `Review Coverage`. Delay buckets and seller minimum as in Decisions. Report pages with the question each visual answers. Reporting window ("to be fixed after profiling", with the reason). Out of scope (copied from the Non-goals). An "Interpretation" note on association vs causation, naming the confounders.
- [ ] **Step 2:** Verify: every KPI on every report page in the spec appears in the KPI table, and Berk reads and agrees with the definitions.
- [ ] **Step 3:** Commit `Add requirements document with KPI definitions`. Show the commit, push after approval.

### Task 3: Raw load

**Files:** Create `requirements.txt`, `data/raw/README.md`, `sql/01_raw/load_raw.sql`, `build.py`, `tests/test_raw_load.py`, `pyproject.toml` (pytest config and `data` marker only).

**Interfaces:**
- Produces: DuckDB file `data/olist.duckdb` with schema `raw` and tables `raw.orders`, `raw.order_items`, `raw.customers`, `raw.sellers`, `raw.products`, `raw.payments`, `raw.reviews`, `raw.geolocation`, `raw.category_translation`, all columns VARCHAR with the original CSV column names.
- Produces: `build.py` with `DB_PATH = ROOT / "data" / "olist.duckdb"`, `LAYERS = ["sql/01_raw"]` (later sessions append to it), `run_sql_file(con: duckdb.DuckDBPyConnection, path: Path) -> None`, `main() -> None`. Paths resolve relative to the repo root, and the DB file is deleted before each build.

- [ ] **Step 1:** Berk downloads the Kaggle archive and unzips it into `data/raw/`. Verify that all 9 CSV files are present.
- [ ] **Step 2:** `requirements.txt` with `duckdb==2.0.0` and `pytest==9.2.0`. Create `.venv` and install. Verify: `.venv/Scripts/python -c "import duckdb; print(duckdb.__version__)"` prints `2.0.0`. Commit `Add Python requirements`.
- [ ] **Step 3: Write the failing test** `tests/test_raw_load.py::test_raw_row_counts` (marked `data`), parametrized over the expected counts: orders 99441, order_items 112650, customers 99441, sellers 3095, products 32951, payments 103886, reviews 99224, geolocation 1000163, category_translation 71. Also `test_raw_columns_are_varchar`.
- [ ] **Step 4:** Run `.venv/Scripts/python -m pytest tests/test_raw_load.py -v`. Expected: FAIL (the DB does not exist).
- [ ] **Step 5:** Write `sql/01_raw/load_raw.sql`: `CREATE SCHEMA raw;` then one `CREATE TABLE raw.<name> AS SELECT * FROM read_csv('data/raw/<file>.csv', header = true, all_varchar = true);` per file. Write `build.py`.
- [ ] **Step 6:** Run `.venv/Scripts/python build.py`, then pytest. Expected: PASS. If a count differs, investigate (the reviews file has comments with embedded newlines and quotes). Do not edit the expected number to match.
- [ ] **Step 7:** `data/raw/README.md`: source URL, download date, file list with row counts, license.
- [ ] **Step 8:** Commits: `Add raw row-count tests`, `Load the nine raw CSVs into DuckDB`, `Add build runner`, `Document raw data source`. Show them, push after approval. **End of Session 1.**

---

## Later sessions (outlined here; each is broken into steps at the start of its session, using what profiling found)

### Session 2: Profiling
- `scripts/run_sql.py <file.sql>`: prints each statement's result.
- One `sql/profiling/profile_<table>.sql` per source table: row count, key uniqueness, nulls per column, value ranges, date coverage. Plus `profile_relationships.sql` for orphan keys between tables.
- Questions that feed the decisions: share of multi-seller orders; orders with 0 or several reviews; reviews linked to several orders; delivered orders without a delivery date; delivery or approval before purchase; categories without an English translation; distribution of delivered orders per seller (to confirm the minimum of 30); monthly order count (to fix the reporting window); share of late orders per bucket (to confirm the buckets).
- `docs/profiling.md`: findings in plain language, each with the query that produced it. One commit per table profile, one for the doc. Any decision change is written back into `docs/requirements.md`.

### Session 3: Staging, star schema, source-to-target mapping
- `sql/02_staging/stg_*.sql`: types, trimmed and lowercased text where needed, renamed columns, English category names, one review per order.
- `sql/03_marts/`: `dim_customer` (grain: `customer_unique_id`), `dim_seller`, `dim_product`, `dim_geography` (state grain + macro-region), `fct_orders`, `fct_order_items`, as in Decisions.
- `docs/data_model.md`: grain of each table with the justification, a Mermaid ER diagram, and the known limitations. `docs/source_to_target.md`: one row per target column with source table and column and the transformation rule. One commit per model and per doc.

### Session 4: Data quality checks and the one-command build
- `sql/04_quality/dq_*.sql`. Each returns violating rows, and `build.py` stops with a non-zero exit code naming the check and the row count. Checks: primary key uniqueness for every mart; referential integrity from each fact to each dimension; no negative price or freight; delivery and approval not before purchase; review score in 1–5; `fct_orders` row count equals the staging orders count; `fct_order_items` revenue reconciles with staging; plus the Review Focus checks above.
- `tests/test_quality_gate.py`: on a temporary DB with one planted violation, the build fails.
- Export marts to `data/marts/*.parquet` with `COPY ... TO ... (FORMAT parquet)`.
- `docs/data_quality.md`: every check, and every known data issue with its count and how it was handled. One commit per check group, one for the export, one for the doc.

### Session 5+: Power BI and README (one page per session)
- 5: Load Parquet, relationships, date table (`powerbi/date_table.m`), base measures in `powerbi/measures.dax`, Overview page.
- 6: Delivery & satisfaction page.
- 7: Seller detail drill-through page.
- 8: Sharing (Publish to web; if the tenant blocks it, a PDF export), screenshots, GIF, final README with the finding (worded as association), model diagram and rebuild steps.
- After 8: a whole-project review with Berk.
- For each page: Turkish step-by-step instructions in chat, Berk builds and sends screenshots, Claude reviews, then commits the `.pbix`, the screenshot and any new DAX.
