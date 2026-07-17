# E-Commerce Sales Data Pipeline: Profiling, Cleaning & Analysis

A SQL-based pipeline that takes a messy 103-row Kaggle e-commerce sales export, profiles its data-quality issues, cleans it into an analysis-ready table, and derives business KPIs from it. Built in SQLite.

Every number in this document was produced by running `sales_pipeline_FULL.sql` against the raw source file and is reproducible from that script.

---

## 1. Dataset

- **Source:** Kaggle, raw file `messy_ecommerce_sales_data.csv` (103 rows, 11 columns, deliberately dirtied for practice)
- **Fields:** id, customer name, order id, order date, product, category, quantity, price, payment method, status, total
- **Output:** `sales100_clean` (100 rows after de-duplication), plus a `data_quality_note` column for flagged records

## 2. Methodology

**Profiling** — before touching the data, it was audited for: duplicate IDs, missing values per column, category spelling/casing variants, date format inconsistency, quantity×price vs. total mismatches, ID sequence gaps, and orders whose line items disagreed with each other (same order ID, different customer/date/payment/status).

**Cleaning** — issues found in profiling were resolved:
- Duplicate IDs de-duplicated (keeping first occurrence)
- Dates parsed from mixed `MM/DD/YYYY`, `DD-MM-YYYY`, and `YYYY-MM-DD` formats into a single standard; unparseable text dates (e.g. `Jan 5 2023`, `abc`) isolated under status `INVALID_DATE`
- Quantity and price validated as genuinely numeric before casting — non-numeric junk (`abd`, `four hundred`) is set to `NULL` and flagged `DATA_ERROR` rather than silently coerced to 0
- Negative quantities treated as returns; negative unit prices corrected to their absolute value
- Every product mapped to exactly one canonical category (previously, the same product could appear under two different categories depending on the row — now resolved to the most common valid category on record for that product)
- Return status unified: the raw data had returns recorded two different ways (a `Returned` status field, and separately, orders with negative quantity/negative total). Both now roll up to a single `RETURNED` status so no return is missed by downstream filters
- Records priced more than 3x their category average are flagged `PRICE_OUTLIER_REVIEW` in `data_quality_note` rather than accepted at face value

**Analysis** — KPIs computed with returns, data errors, and invalid-date rows excluded from "clean" business metrics unless the metric is specifically about them.

## 3. Data Quality Findings

| Issue | Scale |
|---|---|
| Unparseable / corrupted order dates | 38% of records |
| Records with unusable quantity or price | 9% of records |
| Duplicate IDs found and removed | 3 records |
| Overall data hygiene error rate | 47% of records need a repair or exclusion flag |
| Products with inconsistent category before the fix | 1 (`Blender`, recorded as both Home and Electronics) |
| Transactions flagged as statistical price outliers | 1 (`Blender`, priced 6.7x the category average — a $10,000 unit price on a return, likely a data-entry error rather than a real transaction) |

Nearly half the raw file needed some form of repair or flagging before it could be trusted — that's the single most important finding about the dataset itself, independent of any business conclusion drawn from it.

**Note on the flagged outlier:** the $10,000 blender materially changes results depending on whether it's included. With it included, Home's return-to-revenue ratio comes out above 100% and Cash on Delivery looks like by far the riskiest payment channel. With it excluded, Electronics is the clear highest-return category and PayPal is the highest-drag payment method. The figures below are reported **with the outlier excluded**, since a single unverified $10,000 price point shouldn't drive a business narrative — the with-outlier and without-outlier numbers are both shown where they diverge meaningfully, so the sensitivity is visible rather than hidden.

## 4. Core Metrics

| Metric | Value |
|---|---|
| Gross revenue (all non-cancelled, non-error orders) | $132,233.87 |
| Total refund outflow (returns) | $43,922.32 (incl. the flagged outlier) |
| Average order value | $1,542.69 |
| Average unit selling price | $509.87 |
| Average items per basket | 3.03 |
| Return rate (share of all orders) | 14% |
| Cancellation loss | $10,044.74 (7.6% of gross revenue) |

## 5. Revenue by Category

| Category | Revenue Share |
|---|---|
| Clothing | 39.6% |
| Home | 20.9% |
| Sports | 16.2% |
| Books | 13.2% |
| Electronics | 10.2% |

Clothing is the largest revenue category by a wide margin, followed by Home. Electronics is the smallest — worth noting since it's also the category with the highest return risk (below).

## 6. Return Risk by Category

| Category | Return-to-Revenue Ratio (outlier excluded) |
|---|---|
| Electronics | 54.9% |
| Books | 30.5% |
| Home | 25.7% |
| Clothing | 10.9% |
| Sports | 3.9% |

Electronics loses more than half its revenue to returns — the clearest risk signal in the dataset. Books is second, driven mainly by returns on Comics, Biography, Fiction, and Science titles (Books is not a return-free category).

**Highest individual return-rate products** (>15% of that product's own orders returned): T-Shirt (33%), Comics (29%), Blender and Laptop (25% each), Biography, Fiction, Smartphone, and Yoga Mat (20% each), Science (17%).

## 7. Payment Method Analysis

**Revenue contribution:**

| Method | Share of Revenue |
|---|---|
| Cash on Delivery | 32.3% |
| Bank Transfer | 31.5% |
| PayPal | 18.6% |
| Credit Card | 17.6% |

**Refund drag ratio (outlier excluded):**

| Method | Refund Drag |
|---|---|
| PayPal | 27.4% |
| Bank Transfer | 23.6% |
| Cash on Delivery | 21.4% |
| Credit Card | 12.2% |

No payment method is return-free. Credit Card is the lowest-drag channel; PayPal, despite processing the least cash of the four, carries the highest refund ratio relative to its own volume.

## 8. Cancellations & Fulfillment

7.6% of gross revenue ($10,044.74) is lost to pre-fulfillment cancellations — a meaningful and recoverable leak, separate from the return problem.

## 9. Inventory Classification

Segmenting products by volume and value: **Shoes** is both the highest-volume and highest-revenue single product ($14,728.67 total, including returns). Most catalog items fall into a "low volume, high value" pattern rather than high-volume commodity sales — consistent with a small, low-transaction-count dataset rather than a true volume retailer.

---

## 10. Recommendations

**1. Investigate Electronics returns as a genuine priority — but verify the data first.**
Electronics has the highest return ratio in the dataset at 54.9%, which holds up even after removing the price outlier. Before acting on this, confirm the flagged $10,000 blender transaction — it's very likely a data entry error (a $10,000 blender is implausible) and should be corrected or removed at the source before any inventory or supplier decision is made on top of it. Once confirmed, focus the return-cause investigation (damage in transit vs. inaccurate listings) on Laptop and Smartphone specifically, since those are the products actually driving Electronics' return rate.

**2. Treat Books as a real, if moderate, return risk — not a zero-risk category.**
A 30.5% return ratio is the second-highest in the dataset. Comics is the main driver. Worth checking whether this is a description/condition-accuracy issue rather than a product-quality one, since physical media returns are often about mismatched expectations rather than defects.

**3. De-risk Cash on Delivery, but expect a moderate — not dramatic — effect.**
COD's refund drag (21.4%) is close to Bank Transfer's (23.6%) once the outlier is removed, so it isn't the outsized outlier it first appeared to be. A small non-refundable deposit or delivery fee is still reasonable to test, but size the expected impact modestly rather than positioning it as the primary fix.

**4. Recover cancelled orders before shipping.**
7.6% of gross revenue is lost to cancellations. An automated follow-up (SMS/email offering an alternative or a small incentive) at the moment of cancellation is a low-cost way to recover part of this — this recommendation is well-supported by the data and independent of any of the flagged data-quality issues.

**5. Fix data capture at the source, not just downstream.**
47% of incoming records needed repair. Two concrete, low-effort fixes upstream would eliminate most of this: (a) enforce a single date format at the point of entry/export instead of allowing free-text dates, and (b) validate quantity and price as numeric fields before they ever reach a CSV. This would remove the need for a third of this cleaning pipeline entirely.

**6. Build a standing outlier-review step, not a one-time fix.**
The single flagged blender transaction was capable of flipping which category and which payment method looked riskiest. Any pipeline feeding business decisions should flag statistical outliers automatically (as this one now does) and route them to a human check before they influence a report.

---

## 11. Known Limitations

- Date parsing handles numeric `M/D/Y` and `Y/M/D` formats only; text-month formats (`Jan 5 2023`) are correctly excluded but not recovered — a small number of otherwise-valid orders are lost to `INVALID_DATE` as a result.
- The outlier-flagging threshold (3x category average) is a simple heuristic, not a formal statistical test — reasonable for a 100-row dataset, but would need a more rigorous method (e.g. IQR or z-score against a larger sample) at production scale.
- Sample size is small (100 clean records); category- and product-level percentages above should be read as directional signals from this dataset, not as statistically robust population estimates.
