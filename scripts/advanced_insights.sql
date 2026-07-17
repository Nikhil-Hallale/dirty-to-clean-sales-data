-- #######################################################################
-- PART 3: ANALYSIS / KPIs
-- #######################################################################

--  Average Unit Selling Price
SELECT ROUND(SUM(total) / SUM(quantity), 2) AS average_unit_selling_price
FROM sales100_clean
WHERE quantity > 0 AND status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE');

--  Average items per basket
SELECT ROUND(AVG(quantity), 2) AS average_units_per_transaction
FROM sales100_clean
WHERE quantity > 0 AND status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE');

-- Cancellation leakage
SELECT
    ROUND(SUM(CASE WHEN status = 'CANCELLED' THEN total ELSE 0 END), 2) AS cancelled_revenue_loss,
    ROUND(SUM(CASE WHEN status = 'CANCELLED' THEN total ELSE 0 END) * 100.0 /
        NULLIF(SUM(CASE WHEN quantity > 0 THEN total ELSE 0 END), 0), 2) AS cancelled_revenue_percentage
FROM sales100_clean;

--  Status share
SELECT
    status,
    COUNT(*) AS total_transactions,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM sales100_clean), 2) AS status_share_percentage
FROM sales100_clean
GROUP BY status
ORDER BY total_transactions DESC;

--  Clean vs repaired record revenue share
SELECT
    CASE WHEN status IN ('DATA_ERROR', 'INVALID_DATE') THEN 'Repaired/Flawed Records'
         ELSE 'Perfect Ingestion Records' END AS record_integrity_group,
    COUNT(*) AS record_count,
    ROUND(SUM(total), 2) AS revenue_share
FROM sales100_clean
GROUP BY record_integrity_group;

--  Payment gateway revenue contribution
SELECT
    payment_method,
    ROUND(SUM(total), 2) AS cash_flow_processed,
    ROUND(SUM(total) * 100.0 / (SELECT SUM(total) FROM sales100_clean WHERE total > 0), 2) AS payment_revenue_contribution_pct
FROM sales100_clean
WHERE total > 0
GROUP BY payment_method
ORDER BY cash_flow_processed DESC;

--  Gross revenue / refund outflow / net revenue
SELECT ROUND(SUM(total), 2) AS gross_revenue FROM sales100_clean WHERE quantity > 0;


SELECT ABS(ROUND(SUM(total), 2)) AS total_refund_outflow
FROM sales100_clean
WHERE status = 'RETURNED';

SELECT ROUND(SUM(total), 2) AS net_revenue FROM sales100_clean;

--  Average Order Value
SELECT ROUND(AVG(total), 2) AS average_order_value
FROM sales100_clean
WHERE total > 0 AND status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE');

--  Return rate
SELECT ROUND(COUNT(CASE WHEN status = 'RETURNED' THEN 1 END) * 100.0 / COUNT(*), 2) AS return_rate_percentage
FROM sales100_clean;

--  Category revenue share 
SELECT
    category,
    ROUND(SUM(total), 2) AS category_net_revenue,
    ROUND(SUM(total) * 100.0 / (SELECT SUM(total) FROM sales100_clean
        WHERE status NOT IN ('RETURNED','DATA_ERROR','INVALID_DATE')), 2) AS revenue_share_pct
FROM sales100_clean
WHERE status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY category
ORDER BY revenue_share_pct DESC;

--  Top grossing product
SELECT category, product, ROUND(SUM(total), 2) AS total_net_revenue
FROM sales100_clean
GROUP BY category, product
ORDER BY total_net_revenue DESC
LIMIT 1;

--  Return-to-revenue ratio by category
SELECT
    category,
    ROUND(SUM(CASE WHEN status != 'RETURNED' THEN total ELSE 0 END), 2) AS gross_revenue,
    ROUND(ABS(SUM(CASE WHEN status = 'RETURNED' THEN total ELSE 0 END)), 2) AS return_outflow,
    ROUND(
        ABS(SUM(CASE WHEN status = 'RETURNED' THEN total ELSE 0 END)) /
        NULLIF(SUM(CASE WHEN status != 'RETURNED' THEN total ELSE 0 END), 0), 4
    ) AS return_to_revenue_ratio
FROM sales100_clean
GROUP BY category
ORDER BY return_to_revenue_ratio DESC;

--  Toxic products (>15% return rate)
SELECT
    product, category,
    COUNT(*) AS total_transactions,
    COUNT(CASE WHEN status = 'RETURNED' THEN 1 END) AS return_count,
    ROUND(COUNT(CASE WHEN status = 'RETURNED' THEN 1 END) * 100.0 / COUNT(*), 2) AS product_return_rate_pct
FROM sales100_clean
GROUP BY product, category
HAVING product_return_rate_pct > 15.0
ORDER BY product_return_rate_pct DESC;

--  Inventory portfolio classification
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
WHERE status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY product
ORDER BY total_value DESC;

--  Volume vs revenue share by category
WITH TotalMetrics AS (
    SELECT SUM(quantity) AS global_qty, SUM(total) AS global_rev
    FROM sales100_clean
    WHERE status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE')
)
SELECT
    category,
    SUM(quantity) AS units_sold,
    ROUND(SUM(quantity) * 100.0 / (SELECT global_qty FROM TotalMetrics), 2) AS unit_volume_share_pct,
    ROUND(SUM(total), 2) AS net_revenue_generated,
    ROUND(SUM(total) * 100.0 / (SELECT global_rev FROM TotalMetrics), 2) AS revenue_share_pct
FROM sales100_clean
WHERE status NOT IN ('RETURNED', 'DATA_ERROR', 'INVALID_DATE')
GROUP BY category;

--  Payment method refund drag
SELECT
    payment_method,
    ROUND(SUM(CASE WHEN status != 'RETURNED' THEN total ELSE 0 END), 2) AS raw_cash_processed,
    ROUND(ABS(SUM(CASE WHEN status = 'RETURNED' THEN total ELSE 0 END)), 2) AS refund_outflow,
    ROUND(
        ABS(SUM(CASE WHEN status = 'RETURNED' THEN total ELSE 0 END)) /
        NULLIF(SUM(CASE WHEN status != 'RETURNED' THEN total ELSE 0 END), 0), 4
    ) AS gateway_refund_drag_ratio
FROM sales100_clean
GROUP BY payment_method
ORDER BY gateway_refund_drag_ratio DESC;

--  Rows flagged for manual review
SELECT id, product, category, price, quantity, total, data_quality_note
FROM sales100_clean
WHERE data_quality_note IS NOT NULL;

--  Data hygiene error rate
SELECT ROUND(COUNT(CASE WHEN status IN ('DATA_ERROR', 'INVALID_DATE') THEN 1 END) * 100.0 / COUNT(*), 2) AS data_hygiene_error_rate
FROM sales100_clean;
