# Olist E-commerce BI Project: Design

*2026-11-18. Portfolio project by Berk Can Suner.*

## Intent

BI analyst work centers on Power BI and also calls for SQL data profiling, data modeling (star schema), data quality, source-to-target mappings and documentation. Berk's earlier Power BI work (dashboards with target vs. actual tracking) is internal and cannot be shared.

This project is a public example of that BI work. What should set it apart from the many tutorial Olist dashboards is the work behind the dashboard, framed as a real BI engagement: a stakeholder question, requirements, SQL profiling and modeling, data quality checks, and a report that answers the question.

## The business question

Main story (operations): **"How much do late deliveries hurt customer review scores, and which sellers and regions drive the problem?"**

Context (commercial): the size and shape of the business (revenue, orders, average order value, categories, regions, monthly trend), so the operations finding has scale.

The commercial view supports the operations story; it is not a second, equal story. Berk should be able to tell the project in one sentence in an interview: what the problem was, what caused it, and what he would recommend.

## Goals

- A recruiter understands the project from the README in about 2 minutes, with screenshots of the report up front.
- A BI hiring manager sees the full chain: requirements, SQL profiling, star schema, source-to-target mapping, data quality checks, DAX measures, a report built to answer the question.
- SQL does real work and is visible in the repo, not hidden inside the `.pbix`.
- Reproducible: someone can clone the repo, run one command to rebuild the model tables, and open the report.
- Berk can explain every modeling and DAX decision in an interview.

## Non-goals

- No live database or cloud warehouse (no PostgreSQL server, Azure, Fabric, Snowflake).
- No machine learning or forecasting.
- No web app or Streamlit.
- No pixel-perfect custom theme work; a clean, consistent standard look is enough.

## Anti-goals (failure even if it works)

- Looks like a course dashboard: lots of visuals, no question, no finding.
- Causal claims the data can't support. Late delivery and low scores are associated in observational data; say "associated with", and note confounders (for example category, distance, seller) where relevant.
- Transformations Berk can't explain, or DAX copied without understanding.
- Presented on the CV as work experience. It is a personal project.

## Data

Brazilian E-Commerce Public Dataset by Olist (Kaggle), about 100k orders from 2016 to 2018, nine CSV tables: orders, order items, customers, sellers, products, payments, reviews, geolocation, product category name translation. License CC BY-NC-SA 4.0 (non-commercial portfolio use is fine; credit Olist and keep the license note in the README).

Store raw CSVs under `data/raw/` unchanged, with the source URL and download date noted. Kaggle download needs Berk's Kaggle login; the builder asks Berk to download it himself if needed.

## Approaches considered

1. **DuckDB + SQL scripts, then Power BI (chosen).** CSVs loaded into DuckDB; all transformations in versioned `.sql` files (raw, staging, star schema); final tables exported to Parquet; Power BI Desktop imports the Parquet files. Free, no server, fully visible on GitHub, same tool as the Hillstrom project. Trade-off: Power BI reads files, not a live database.
2. **Local PostgreSQL, then Power BI.** Closer to a real warehouse, Power BI connects to a database. Rejected: setup and maintenance cost, and a reviewer can't easily re-run it.
3. **Everything in Power Query.** Fastest. Rejected: no visible SQL, and transformations stay inside the `.pbix` where GitHub can't show them.

Berk picked approach 1. Power Query is still used for small things (for example the date table or light shaping) so that skill is visible too.

## How it's built (decided)

- Tools: DuckDB (SQL), Python only as a thin runner if needed, Power BI Desktop (Windows, free).
- SQL in `.sql` files in layers: raw load, staging (typed, cleaned, renamed), marts (star schema). One command rebuilds everything from raw CSVs.
- Star schema with an order-item grain fact table (or order grain if the builder can justify it) plus dimensions for customer, seller, product, date and geography. The grain choice must be written down and explained, because it decides how revenue and review scores aggregate.
- Separate public GitHub repo under github.com/berkcansuner.
- **Who does what (Berk's decision):** Claude Code writes the SQL, quality checks, build command, docs, DAX measure definitions and README. Berk builds the `.pbix` himself in Power BI Desktop, following step-by-step instructions from Claude for each page: loading the Parquet files, setting relationships, creating the date table, pasting DAX measures, choosing and configuring visuals. Berk saves the `.pbix` and screenshots; Claude reviews them and commits. This keeps the report something Berk can defend in an interview. After the project, the whole project is reviewed with Berk.

## Deliverables

1. **Requirements doc (short).** Stakeholder, business questions, KPIs with exact definitions (for example: what counts as "late" = delivered after the estimated delivery date), report pages, and out-of-scope items. One to two pages, written like a real BI requirements note.
2. **Data profiling.** SQL queries that profile each source table: row counts, keys and their uniqueness, nulls, value ranges, date coverage, orphan keys between tables. Findings summarized in a short markdown note.
3. **Source-to-target mapping.** A table (markdown or CSV) mapping each target column in the star schema to its source table/column and the transformation rule.
4. **Data quality checks.** SQL checks that run with the build and fail loudly: key uniqueness, referential integrity between fact and dimensions, no negative prices, delivery dates not before purchase dates, and similar. Known data issues (for example orders with no review, or reviews with multiple orders) documented with how they were handled.
5. **Power BI report** (`.pbix` in the repo), pages:
   - **Overview (commercial):** revenue, orders, average order value, monthly trend, category and region breakdowns.
   - **Delivery & satisfaction (operations, the main story):** on-time vs. late rate, average review score by delivery delay bucket, trend of late rate, worst sellers and regions by late rate (with a minimum order count so small sellers don't dominate).
   - **Seller detail (drill-through):** one seller's volume, late rate and review scores.
   - DAX measures with clear names; a dedicated date table; consistent number formats.
6. **README.** The question, the finding in two or three sentences, screenshots of each page, a short GIF, the data model diagram, how to rebuild, and links to the requirements, profiling, mapping and quality docs.
7. **Sharing.** First try "Publish to web". If the account's tenant blocks it, fall back to screenshots, GIF and a PDF export of the report in the repo.

## Constraints

- Must run on Berk's Windows laptop with free tools.
- Berk must be able to explain every step; explanations in the docs are plain language.
- Code, SQL, docs and README in English. Conversation with Berk in Turkish.
- Work is done incrementally over several days and committed as it happens. Rules:
  - Small commits per meaningful unit (one SQL model, one quality check, one doc, one report page). No backdating, no squashing, no history rewrites. Work on `main`, no PR workflow.
  - Push after each step, showing Berk the commits and getting his approval first.
  - *Pacing (Claude's call):* spread the work over at least five working sessions on different days, one deliverable group per session, roughly: (1) repo setup, requirements doc, raw load; (2) profiling; (3) staging, star schema, source-to-target mapping; (4) quality checks and build command; (5+) Power BI pages and README. Target finish about two weeks after start.
- *Repo (Claude's call, as with Hillstrom):* public from the first push, under github.com/berkcansuner, suggested name `olist-delivery-bi`. Created by the builder only after Berk approves. The first push holds only the README skeleton, this design doc and the folder structure, so there is no half-finished work on show at the start.

## Left to the builder

- Exact folder layout and naming conventions for SQL layers.
- Fact table grain (with a written justification), and whether to add a second fact table (for example reviews).
- Delay bucket boundaries and the minimum order count for seller rankings, as long as they are stated in the requirements doc.
- Which data quality checks beyond the listed ones.
- Chart choices and layout, provided each visual serves a question in the requirements doc.
