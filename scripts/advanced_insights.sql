-- ====================================================================
-- PROJECT: SALES DATA ADVANCED BUSINESS INTELLIGENCE (BI)
-- OBJECTIVE: Evaluate structural financial risk, product elasticity, 
--            wallet share dynamics, and data pipeline value metrics.
-- ====================================================================

-- ====================================================================
-- SECTION 1: REVENUE RISK & RETURN PROFILING
-- ====================================================================

-- 1A. Return-to-Revenue Ratio by Product Category
-- Objective: Identify which categories experience the highest relative revenue leakage.
SELECT 
    category,
    ROUND(SUM(CASE WHEN status != 'RETURN' THEN total ELSE 0 END), 2) AS gross_revenue,
    ROUND(ABS(SUM(CASE WHEN status = 'RETURN' THEN total ELSE 0 END)), 2) AS return_outflow,
    ROUND(
        ABS(SUM(CASE WHEN status = 'RETURN' THEN total ELSE 0 END)) / 
        NULLIF(SUM(CASE WHEN status != 'RETURN' THEN total ELSE 0 END), 0), 
        4
    ) AS return_to_revenue_ratio
FROM sales100_clean
GROUP BY category
ORDER BY return_to_revenue_ratio DESC;

-- 1B. Toxic Products (High-Volume, High-Return Anomalies)
-- Objective: Isolate volatile inventory items where the return rate crosses a critical 15% threshold.
SELECT 
    product,
    category,
    COUNT(*) AS total_transactions,
    COUNT(CASE WHEN status = 'RETURN' THEN 1 END) AS return_count,
    ROUND((COUNT(CASE WHEN status = 'RETURN' THEN 1 END) * 100.0) / COUNT(*), 2) AS product_return_rate_pct
FROM sales100_clean
GROUP BY product, category
HAVING product_return_rate_pct > 15.0
ORDER BY product_return_rate_pct DESC;


-- ====================================================================
-- SECTION 2: MARKET BASKET & CROSS-CATEGORICAL PERFORMANCE
-- ====================================================================

-- 2A. Product Pricing Elasticity Matrix
-- Objective: Evaluate how fluctuating price points impact actual quantities sold.
SELECT 
    product,
    price AS unit_price,
    SUM(quantity) AS total_units_sold,
    ROUND(SUM(total), 2) AS total_net_revenue
FROM sales100_clean
WHERE status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY product, price
ORDER BY product ASC, unit_price DESC;

-- 2B. Category Dominance Index
-- Objective: Measure what percentage of overall profit relies on a single product category.
SELECT 
    category,
    ROUND(SUM(total), 2) AS category_net_revenue,
    ROUND(
        (SUM(total) * 100.0) / (SELECT SUM(total) FROM sales100_clean), 
        2
    ) AS contribution_percentage
FROM sales100_clean
GROUP BY category
ORDER BY contribution_percentage DESC;


-- ====================================================================
-- SECTION 3: PAYMENT SYSTEM & BEHAVIORAL DYNAMICS
-- ====================================================================

-- 3A. Ticket-Size vs. Payment Channel Correlation
-- Objective: Discover if specific payment options naturally attract larger order values (AOV).
SELECT 
    payment_method,
    COUNT(*) AS successful_orders,
    ROUND(AVG(total), 2) AS average_ticket_size_aov
FROM sales100_clean
WHERE total > 0 AND status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY payment_method
ORDER BY average_ticket_size_aov DESC;

-- 3B. Payment Method vs. Return Probability
-- Objective: Assess whether certain payment channels are statistically linked to higher return rates.
SELECT 
    payment_method,
    COUNT(*) AS total_initiated_orders,
    COUNT(CASE WHEN status = 'RETURN' THEN 1 END) AS return_count,
    ROUND((COUNT(CASE WHEN status = 'RETURN' THEN 1 END) * 100.0) / COUNT(*), 2) AS return_probability_pct
FROM sales100_clean
GROUP BY payment_method
ORDER BY return_probability_pct DESC;


-- ====================================================================
-- SECTION 4: ADVANCED OPERATIONAL EFFICIENCY
-- ====================================================================

-- 4A. Data Integrity Cost Matrix (Trapped "Ghost Revenue")
-- Objective: Quantify the literal dollar amount locked inside broken raw data pipelines.
SELECT 
    status AS pipeline_flag,
    COUNT(*) AS broken_record_count,
    ROUND(SUM(quantity * price), 2) AS trapped_ghost_revenue
FROM sales100_clean
WHERE status IN ('DATA_ERROR', 'INVALID_DATE')
GROUP BY status;

-- 4B. Inventory Portfolio Classification Matrix (Volume-to-Value)
-- Objective: Segment items into strategic quadrants (Stars, Luxury, Commodities, Dead Stock).
SELECT 
    product,
    SUM(quantity) AS total_volume,
    ROUND(SUM(total), 2) AS total_value,
    CASE 
        WHEN SUM(quantity) >= 20 AND SUM(total) >= 500 THEN 'STAR (High Volume / High Value)'
        WHEN SUM(quantity) < 20  AND SUM(total) >= 500 THEN 'LUXURY (Low Volume / High Value)'
        WHEN SUM(quantity) >= 20 AND SUM(total) < 500  THEN 'COMMODITY (High Volume / Low Value)'
        ELSE 'DEAD STOCK (Low Volume / Low Value)'
    END AS inventory_classification
FROM sales100_clean
WHERE status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY product
ORDER BY total_value DESC;


--=====================================================================
--Purpose: Determines whether a product category is highly efficient. 
--          It compares its share of total units sold vs. its share of 
--          total net revenue.
-- ====================================================================
WITH TotalMetrics AS (
    SELECT 
        SUM(quantity) AS global_qty,
        SUM(total) AS global_rev
    FROM sales100_clean
    WHERE status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE')
)
SELECT 
    category,
    SUM(quantity) AS units_sold,
    ROUND((SUM(quantity) * 100.0) / (SELECT global_qty FROM TotalMetrics), 2) AS unit_volume_share_pct,
    ROUND(SUM(total), 2) AS net_revenue_generated,
    ROUND((SUM(total) * 100.0) / (SELECT global_rev FROM TotalMetrics), 2) AS revenue_share_pct,
FROM sales100_clean
WHERE status NOT IN ('RETURN', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY category;


-- ====================================================================
-- KPI 5D. Gateway Revenue Integrity Index (Refund Drag Coefficient)
-- Purpose: Analyzes how much of the capital entering each payment gateway 
--          is dragged back out by returns, helping the finance team negotiate 
--          better processing fee rates.
-- ====================================================================
SELECT 
    payment_method,
    ROUND(SUM(CASE WHEN status != 'RETURN' THEN total ELSE 0 END), 2) AS raw_cash_processed,
    ROUND(ABS(SUM(CASE WHEN status = 'RETURN' THEN total ELSE 0 END)), 2) AS refund_outflow,
    ROUND(
        ABS(SUM(CASE WHEN status = 'RETURN' THEN total ELSE 0 END)) / 
        NULLIF(SUM(CASE WHEN status != 'RETURN' THEN total ELSE 0 END), 0), 4
    ) AS gateway_refund_drag_ratio
FROM sales100_clean
GROUP BY payment_method
ORDER BY gateway_refund_drag_ratio DESC;
