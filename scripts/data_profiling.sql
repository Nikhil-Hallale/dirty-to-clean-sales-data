-- #######################################################################
-- PART 1: DATA PROFILING
-- #######################################################################

-- 1.1 Duplicate ID check
SELECT id, COUNT(id) AS occurrence_count
FROM sales100
GROUP BY id
HAVING COUNT(id) > 1;

-- 1.2 Null / completeness audit
SELECT
    SUM(CASE WHEN id IS NULL OR id = '' THEN 1 ELSE 0 END) AS missing_ids,
    SUM(CASE WHEN customer_name IS NULL OR customer_name = '' THEN 1 ELSE 0 END) AS missing_names,
    SUM(CASE WHEN order_date IS NULL OR order_date = '' THEN 1 ELSE 0 END) AS missing_dates,
    SUM(CASE WHEN category IS NULL OR category = '' THEN 1 ELSE 0 END) AS missing_categories,
    SUM(CASE WHEN quantity IS NULL OR quantity = '' THEN 1 ELSE 0 END) AS missing_quantities,
    SUM(CASE WHEN price IS NULL OR price = '' THEN 1 ELSE 0 END) AS missing_prices,
    SUM(CASE WHEN total IS NULL OR total = '' THEN 1 ELSE 0 END) AS missing_totals
FROM sales100;

-- 1.3 Category spelling / casing variants
SELECT category, COUNT(*) AS entry_count
FROM sales100
GROUP BY category;

-- 1.4 Date format chaos check
SELECT
    order_date,
    COUNT(*) AS total_occurrences,
    CASE
        WHEN order_date IS NULL OR TRIM(order_date) = '' THEN 'MISSING / BLANK DATE'
        WHEN order_date LIKE '____-__-__' THEN 'CLEAN DATE'
        WHEN order_date GLOB '*[a-zA-Z]*' THEN 'CORRUPT TEXT (e.g. abc, Jan 5 2023)'
        ELSE 'FORMAT CHAOS (e.g. MM/DD/YYYY, DD-MM-YYYY)'
    END AS date_status
FROM sales100
GROUP BY order_date, date_status
ORDER BY date_status DESC;

-- 1.5 Business-logic check: does quantity * price = total?
SELECT
    id, quantity, price, total,
    (CAST(quantity AS INT) * CAST(price AS DECIMAL)) AS calculated_total,
    (CAST(total AS DECIMAL) - (CAST(quantity AS INT) * CAST(price AS DECIMAL))) AS discrepancy
FROM sales100
WHERE CAST(quantity AS INT) > 0 AND CAST(price AS DECIMAL) > 0 AND CAST(total AS DECIMAL) > 0
  AND ABS(CAST(total AS DECIMAL) - (CAST(quantity AS INT) * CAST(price AS DECIMAL))) > 0.01;

-- 1.6 Sequence gap analysis
SELECT current_id, next_id, (next_id - current_id - 1) AS missing_ids_count
FROM (
    SELECT CAST(id AS INT) AS current_id,
           LEAD(CAST(id AS INT)) OVER (ORDER BY CAST(id AS INT)) AS next_id
    FROM sales100
)
WHERE next_id IS NOT NULL AND next_id - current_id > 1;

-- 1.7 Multi-item order consistency check
SELECT
    order_id,
    COUNT(DISTINCT customer_name) AS unique_customers,
    COUNT(DISTINCT order_date) AS unique_dates,
    COUNT(DISTINCT payment_method) AS unique_payments,
    COUNT(DISTINCT status) AS unique_statuses
FROM sales100
WHERE order_id IS NOT NULL AND TRIM(order_id) != ''
GROUP BY order_id
HAVING unique_customers > 1 OR unique_dates > 1 OR unique_payments > 1 OR unique_statuses > 1;
