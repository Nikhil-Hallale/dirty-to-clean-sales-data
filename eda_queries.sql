-- ====================================================================
-- PROJECT: SALES DATA EXPLORATORY DATA ANALYSIS (EDA)
-- Phase 4: Business Intelligence & Revenue Metric Extraction
-- OBJECTIVE: Execute aggregate core KPIs, isolate revenue leakage,
--            and track categorical performance from sales100_clean.
-- ====================================================================

-- ====================================================================
-- KPI 1: Gross Revenue (Top-Line Sales Volume)
-- ====================================================================
SELECT ROUND(SUM(total), 2) AS gross_revenue
FROM sales100_clean
WHERE quantity > 0;

-- ====================================================================
-- KPI 2: Total Refund Outflow (Revenue Leakage)
-- ====================================================================
SELECT ABS(ROUND(SUM(total), 2)) AS total_refund_outflow
FROM sales100_clean
WHERE quantity < 0 AND status = 'RETURN';

-- ====================================================================
-- KPI 3: Net Revenue (Realized Retained Profit)
-- ====================================================================
-- Note: Since return totals are already negative values, a simple SUM 
-- balances gross revenue and refunds perfectly without mathematical doubling.
SELECT ROUND(SUM(total), 2) AS net_revenue
FROM sales100_clean;

-- ====================================================================
-- KPI 4: Average Order Value (AOV)
-- ====================================================================
-- Excludes returns and system errors to calculate the true average of successful transactions
SELECT ROUND(AVG(total), 2) AS average_order_value
FROM sales100_clean
WHERE total > 0 
  AND status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE');

-- ====================================================================
-- KPI 5: Return Rate Percentage (Operational Performance)
-- ====================================================================
SELECT ROUND((COUNT(CASE WHEN status = 'RETURN' THEN 1 END) * 100.0) / COUNT(*), 2) AS return_rate_percentage
FROM sales100_clean;

-- ====================================================================
-- KPI 6: Total Product Units Standardized (Total Sales Volume)
-- ====================================================================
SELECT SUM(quantity) AS total_units_sold
FROM sales100_clean
WHERE quantity > 0;

-- ====================================================================
-- KPI 7 & 8: Categorical & Product Value Distributions (AOV & Profitability)
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
-- KPI 9: Payment Method Distribution (Share of Wallet Share)
-- ====================================================================
SELECT payment_method, COUNT(*) AS transaction_count
FROM sales100_clean
GROUP BY payment_method
ORDER BY transaction_count DESC;

-- ====================================================================
-- KPI 10: Operational Pipeline Error Rate (Data Hygiene Index)
-- ====================================================================
-- Tracks the percentage of incoming records containing fatal system errors
SELECT ROUND((COUNT(CASE WHEN status IN ('DATA_ERROR', 'INVALID_DATE') THEN 1 END) * 100.0) / COUNT(*), 2) AS data_hygiene_error_rate
FROM sales100_clean;
