-- ====================================================================
-- PROJECT: SALES DATA EXPLORATORY DATA ANALYSIS (EDA)
-- OBJECTIVE: Execute aggregate core KPIs, isolate revenue leakage,
--            and track categorical performance from sales100_clean.
-- ====================================================================

-- ====================================================================
-- KPI 1: Average Unit Selling Price (ASP)
-- Industry Purpose: Measures the average retail value of a single item 
--                   moved, isolating individual unit values from overall order totals.
-- ====================================================================
SELECT 
    ROUND(SUM(total) / SUM(quantity), 2) AS average_unit_selling_price
FROM sales100_clean
WHERE quantity > 0 
  AND status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE');


-- ====================================================================
-- KPI 2: Average Items Per Basket (Units Per Transaction - UPT)
-- Industry Purpose: Measures cart density. High UPT indicates strong 
--                   cross-selling and product bundling performance.
-- ====================================================================
SELECT 
    ROUND(AVG(quantity), 2) AS average_units_per_transaction
FROM sales100_clean
WHERE quantity > 0 
  AND status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE');


-- ====================================================================
-- KPI 3: Cancelled Capital Leakage Rate (Fulfillment Loss)
-- Industry Purpose: Calculates potential revenue lost to system or 
--                   buyer cancellations before shipping occurs.
-- ====================================================================
SELECT 
    ROUND(SUM(CASE WHEN status = 'CANCELLED' THEN total ELSE 0 END), 2) AS cancelled_revenue_loss,
    ROUND(
        (SUM(CASE WHEN status = 'CANCELLED' THEN total ELSE 0 END) * 100.0) / 
        NULLIF(SUM(CASE WHEN quantity > 0 THEN total ELSE 0 END), 0), 2
    ) AS cancelled_revenue_percentage
FROM sales100_clean;


-- ====================================================================
-- KPI 4: Logistics Status Share (Order Fulfillment Velocity)
-- Industry Purpose: Evaluates warehouse throughput by tracking the exact 
--                   percentage of orders currently in processing, shipping, or delivery.
-- ====================================================================
SELECT 
    status,
    COUNT(*) AS total_transactions,
    ROUND((COUNT(*) * 100.0) / (SELECT COUNT(*) FROM sales100_clean), 2) AS status_share_percentage
FROM sales100_clean
GROUP BY status
ORDER BY total_transactions DESC;


-- ====================================================================
-- KPI 5: Clean vs. Repaired Record Revenue Share (The ETL ROI Metric)
-- Industry Purpose: Directly quantifies the business value of your pipeline 
--                   by proving how much company revenue was saved through clean-up.
-- ====================================================================
SELECT 
    CASE 
        WHEN status IN ('DATA_ERROR', 'INVALID_DATE') THEN 'Repaired/Flawed Records'
        ELSE 'Perfect Ingestion Records'
    END AS record_integrity_group,
    COUNT(*) AS record_count,
    ROUND(SUM(total), 2) AS revenue_share
FROM sales100_clean
GROUP BY record_integrity_group;


-- ====================================================================
-- KPI 6: Payment Gateway Wallet Share (Revenue Contribution Density)
-- Industry Purpose: Identifies which checkout option processes the largest share 
--                   of actual business cash flow (not just transaction count).
-- ====================================================================
SELECT 
    payment_method,
    ROUND(SUM(total), 2) AS cash_flow_processed,
    ROUND(
        (SUM(total) * 100.0) / (SELECT SUM(total) FROM sales100_clean WHERE total > 0), 2
    ) AS payment_revenue_contribution_pct
FROM sales100_clean
WHERE total > 0
GROUP BY payment_method
ORDER BY cash_flow_processed DESC;

-- ====================================================================
-- KPI 7: Gross Revenue (Top-Line Sales Volume)
-- ====================================================================
SELECT ROUND(SUM(total), 2) AS gross_revenue
FROM sales100_clean
WHERE quantity > 0;

-- ====================================================================
-- KPI 8: Total Refund Outflow (Revenue Leakage)
-- ====================================================================
SELECT ABS(ROUND(SUM(total), 2)) AS total_refund_outflow
FROM sales100_clean
WHERE quantity < 0 AND status = 'RETURN';

-- ====================================================================
-- KPI 9: Net Revenue (Realized Retained Profit)
-- ====================================================================
-- Note: Since return totals are already negative values, a simple SUM 
-- balances gross revenue and refunds perfectly without mathematical doubling.
SELECT ROUND(SUM(total), 2) AS net_revenue
FROM sales100_clean;

-- ====================================================================
-- KPI 10: Average Order Value (AOV)
-- ====================================================================
-- Excludes returns and system errors to calculate the true average of successful transactions
SELECT ROUND(AVG(total), 2) AS average_order_value
FROM sales100_clean
WHERE total > 0 
  AND status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE');

-- ====================================================================
-- KPI 10: Return Rate Percentage (Operational Performance)
-- ====================================================================
SELECT ROUND((COUNT(CASE WHEN status = 'RETURN' THEN 1 END) * 100.0) / COUNT(*), 2) AS return_rate_percentage
FROM sales100_clean;

-- ====================================================================
-- KPI 11: Total Product Units Standardized (Total Sales Volume)
-- ====================================================================
SELECT SUM(quantity) AS total_units_sold
FROM sales100_clean
WHERE quantity > 0;

-- ====================================================================
-- KPI 12 & 13: Categorical & Product Value Distributions (AOV & Profitability)
-- ====================================================================
-- Breakdown of Average Order Values across distinct categories
SELECT category, ROUND(AVG(total), 2) AS category_avg_order_value
FROM sales100_clean
WHERE total > 0
GROUP BY category
ORDER BY category_avg_order_value DESC;

-- Granular breakdown of Average Order Values by Product within Categories
SELECT category, product, ROUND(AVG(total), 2) AS product_avg_order_value
FROM sales100_clean
WHERE total > 0
GROUP BY category, product
ORDER BY product_avg_order_value DESC;

-- Targeted Top Performer: Single highest grossing product by total net revenue
SELECT category, product, ROUND(SUM(total), 2) AS total_net_revenue
FROM sales100_clean
GROUP BY category, product
ORDER BY total_net_revenue DESC
LIMIT 1;

-- Regional Return Analysis: Total count of returns isolated by high-risk categories
SELECT category, COUNT(CASE WHEN status = 'RETURN' THEN 1 END) AS total_return_count
FROM sales100_clean
GROUP BY category
ORDER BY total_return_count DESC;

-- ====================================================================
-- KPI 14: Payment Method Distribution (Share of Wallet Share)
-- ====================================================================
SELECT payment_method, COUNT(*) AS transaction_count
FROM sales100_clean
GROUP BY payment_method
ORDER BY transaction_count DESC;

-- ====================================================================
-- KPI 15: Operational Pipeline Error Rate (Data Hygiene Index)
-- ====================================================================
-- Tracks the percentage of incoming records containing fatal system errors
SELECT ROUND((COUNT(CASE WHEN status IN ('DATA_ERROR', 'INVALID_DATE') THEN 1 END) * 100.0) / COUNT(*), 2) AS data_hygiene_error_rate
FROM sales100_clean;
