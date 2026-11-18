# Requirements: Delivery Performance and Customer Satisfaction

*Version 1, 2026-11-18. Values marked "after profiling" are confirmed in [profiling.md](profiling.md) and updated here.*

## 1. Stakeholder and purpose

**Stakeholder (hypothetical):** Head of Customer Experience at Olist, a Brazilian e-commerce marketplace that connects small sellers to customers. The stakeholder is invented to frame the work as a BI request; this is a personal portfolio project.

**Request:** "Customers complain about late deliveries. I need to know how much late delivery is associated with worse review scores, and which sellers and regions I should look at first."

**Decisions the report supports:** which sellers to review for delivery performance, which regions need better delivery estimates or logistics, and how big the problem is relative to the business.

## 2. Business questions

Main (operations):

1. What share of delivered orders arrives late, and how has that changed over time?
2. How do review scores differ between on-time and late orders, and by how many days late?
3. Which sellers and which customer states have the highest late rates, among those with enough orders to judge?

Context (commercial):

4. How large is the business (revenue, orders, average order value), and how is it split by month, product category and customer state?

**Interpretation rule:** The data is observational. The report shows how late delivery and review scores move together ("associated with"); it does not show that one causes the other. Other factors such as product category, distance between seller and customer, and the seller itself can affect both. Where a comparison could be driven by these, the report says so.

## 3. Definitions

| Term | Definition |
|---|---|
| Order | One `order_id`. |
| Purchase date | Date part of `order_purchase_timestamp`. All time axes and the date filter use this date. |
| Valid order | An order whose status is not `canceled` or `unavailable`. |
| Delivered order | `order_status = 'delivered'` and a non-null customer delivery date. |
| Delay days | Delivered date minus estimated delivery date, both as dates (no time of day). Negative means early. |
| Late order | A delivered order with delay days > 0. Comparing dates, not timestamps, because the estimate is stored at midnight: a delivery at 15:00 on the promised day is on time. |
| Delay bucket | `Early` (< 0), `On estimated day` (0), `1-3 days late`, `4-7 days late`, `8-14 days late`, `15+ days late`. |
| Review score | One review per order: if an order has several, the latest by answer time. Scale 1–5. |
| Region | Customer state (delivery destination), grouped into Brazil's five macro-regions: North, Northeast, Central-West, Southeast, South. |

## 4. KPIs

| KPI | Formula | Population |
|---|---|---|
| Revenue | Sum of item `price`, excluding freight. Currency BRL. This is merchandise value sold through the marketplace, not Olist's own income (Olist earns a commission). | Items of valid orders |
| Orders | Count of distinct orders | Valid orders |
| Average Order Value | Revenue / Orders | Valid orders |
| Delivered Orders | Count of delivered orders | Delivered orders |
| Late Rate | Late orders / delivered orders | Delivered orders |
| Avg Delay Days (late) | Average delay days | Late orders |
| Avg Review Score | Average review score, each order counted once | Delivered orders with a review |
| Low Review Rate | Orders with score 1 or 2 / orders with a review | Delivered orders with a review |
| Review Coverage | Delivered orders with a review / delivered orders | Delivered orders |

Measures at seller or category level count **distinct orders**, so an order with several items counts once. An order with items from several sellers counts for each of those sellers; the share of such orders is reported in profiling.

**Ranking minimum:** sellers and states are ranked only if they have at least **30 delivered orders** in the selected period. Below that, one or two late orders swing the rate too much. (Threshold confirmed after profiling.)

**Reporting window:** months at the start and end of the data with very few orders are excluded from trends. The exact window is fixed after profiling.

## 5. Report pages

**Overview (commercial context)**
- KPI cards: Revenue, Orders, Average Order Value. *How large is the business?*
- Monthly revenue and orders. *Is it growing?*
- Revenue by product category (top 10) and by customer state. *Where does the volume come from?*

**Delivery & satisfaction (main story)**
- KPI cards: Delivered Orders, Late Rate, Avg Review Score, Low Review Rate. *How big is the problem?*
- Avg Review Score and Low Review Rate by delay bucket. *How do scores change as delays grow?*
- Monthly Late Rate. *Is it getting better or worse?*
- Late Rate by customer state, with ranking minimum. *Which regions drive it?*
- Top sellers by Late Rate, with ranking minimum and order count shown. *Which sellers drive it?*

**Seller detail (drill-through from a seller)**
- KPI cards for the seller: Orders, Revenue, Late Rate, Avg Review Score, compared with the marketplace average. *Is this seller worse than average?*
- Monthly orders and Late Rate for the seller. *Is it a recent problem?*
- Review score distribution (1–5) for the seller's delivered orders. *How unhappy are its customers?*

A shared filter panel offers the purchase date range and macro-region.

## 6. Out of scope

- Live database, cloud warehouse, scheduled refresh.
- Forecasting, machine learning, causal effect estimates.
- Text analysis of review comments (Portuguese free text).
- Payment analysis (instalments, payment types).
- Maps (state-level bar charts answer the regional question without geocoding).
- Custom visual theme.
