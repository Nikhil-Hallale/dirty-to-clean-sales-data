-- =====================================================================
-- STEP 1: Database Schema & Metadata Audit
-- Objective: Identify current column data types and structural rules.
-- =====================================================================

PRAGMA table_info(sales100);-

  -- ====================================================================
-- PROJECT: DIRTY-TO-CLEAN SALES DATA PIPELINE
-- Phase 2: Data Profiling & Anomaly Detection
-- ====================================================================

-- STEP 1: Identify Duplicate Transactions
-- Finding which IDs appear more than once in the dataset
SELECT 
    id, 
    COUNT(id) AS occurrence_count
FROM sales100
GROUP BY id 
HAVING COUNT(id) > 1;


-- STEP 2: Verify Duplicate Data Integrity
-- Extracting the full rows for the flagged IDs to inspect the differences
SELECT *
FROM sales100
WHERE id IN (142, 146, 175)
ORDER BY id;

-- ====================================================================
-- STEP 3: Data Completeness & Null Value Audit
-- Objective: Scan every column to check for empty cells or missing critical metrics.
-- ====================================================================
SELECT 
    SUM(CASE WHEN id IS NULL OR id = '' THEN 1 ELSE 0 END) AS missing_ids,
    SUM(CASE WHEN customer_name IS NULL OR customer_name = '' THEN 1 ELSE 0 END) AS missing_names,
    SUM(CASE WHEN order_id IS NULL OR order_id = '' THEN 1 ELSE 0 END) AS missing_order_ids,
    SUM(CASE WHEN product IS NULL OR product = '' THEN 1 ELSE 0 END) AS missing_products,
    SUM(CASE WHEN category IS NULL OR category = '' THEN 1 ELSE 0 END) AS missing_categories,
    SUM(CASE WHEN quantity IS NULL OR quantity = '' THEN 1 ELSE 0 END) AS missing_quantities,
    SUM(CASE WHEN price IS NULL OR price = '' THEN 1 ELSE 0 END) AS missing_prices,
    SUM(CASE WHEN payment_method IS NULL OR payment_method = '' THEN 1 ELSE 0 END) AS missing_payment_methods,
    SUM(CASE WHEN status IS NULL OR status = '' THEN 1 ELSE 0 END) AS missing_statuses,
    SUM(CASE WHEN total IS NULL OR total = '' THEN 1 ELSE 0 END) AS missing_totals
FROM sales100;

-- ====================================================================
-- STEP 4: Numeric Outlier & Sanity Check
-- Objective: Scan columns to check for negative numbers, zeroes, or extreme values.
-- Note: CAST() is used because numeric columns were imported as text types.
-- ====================================================================

-- 1. Identify Negative Values or Unexpected Zeroes
SELECT *
FROM sales100
WHERE CAST(quantity AS INT) <= 0
   OR CAST(price AS DECIMAL) <= 0
   OR CAST(total AS DECIMAL) <= 0;

-- 2. Identify Extreme Outliers (Typing Errors / System Bugs)
-- Scanning for unusually high single-purchase quantities
SELECT *
FROM sales100
WHERE CAST(quantity AS INT) > 100
ORDER BY CAST(quantity AS INT) DESC;

-- ====================================================================
-- STEP 5: Text Standardization & Consistency Audit
-- Objective: Scan categorical columns for variations, typos, or casing mismatches.
-- ====================================================================

-- 1. Inspect Category Standardizations
SELECT 
    category, 
    COUNT(*) AS entry_count
FROM sales100
GROUP BY category;

-- 2. Inspect Product Naming Consistency
SELECT 
    product, 
    COUNT(*) AS entry_count
FROM sales100
GROUP BY product;

-- ====================================================================
-- STEP 6: Date Integrity, Timeline, & Format Chaos Check
-- Objective: Categorize all date-related issues (missing, format chaos, 
--            corrupt text, or timeline out-of-bounds anomalies).
-- ====================================================================

SELECT 
    order_date,
    COUNT(*) AS total_occurrences,
    CASE 
        -- 1. Catch missing, null, or blank spaces
        WHEN order_date IS NULL 
             OR TRIM(order_date) = '' 
             OR order_date IN ('NaN', 'null') 
             THEN 'MISSING / BLANK DATE'

        -- 2. Validate standard layout (YYYY-MM-DD) and check timeline boundaries
        WHEN order_date LIKE '____-__-__' THEN 
             CASE 
                 WHEN date(order_date) < '2010-01-01' OR date(order_date) > '2026-12-31' 
                      THEN 'OUT OF BOUNDS (Ancient/Future)'
                 ELSE 'CLEAN DATE ✓'
             END

        -- 3. If layout is wrong, check for literal non-numeric text strings (e.g., 'abc')
        WHEN order_date GLOB '*[a-zA-Z]*' 
             THEN 'CORRUPT TEXT (e.g., abc)'

        -- 4. If it has no letters, isn't blank, but still isn't YYYY-MM-DD -> Format Chaos!
        ELSE 'FORMAT CHAOS (e.g., MM/DD/YYYY)'
    END AS date_status
FROM sales100
GROUP BY order_date, date_status
ORDER BY date_status DESC;

-- ====================================================================
-- STEP 7: Business Logic & Cross-Column Validation
-- Objective: Verify if Quantity * Price matches the Total column.
-- ====================================================================

SELECT 
    id,
    quantity,
    price,
    total,
    -- Calculate what the total should be
    (CAST(quantity AS INT) * CAST(price AS DECIMAL)) AS calculated_total,
    -- Find the exact variance
    (CAST(total AS DECIMAL) - (CAST(quantity AS INT) * CAST(price AS DECIMAL))) AS discrepancy
FROM sales100
WHERE 
    -- Ignore rows where we already know the data is corrupted/blank
    CAST(quantity AS INT) > 0 
    AND CAST(price AS DECIMAL) > 0
    AND CAST(total AS DECIMAL) > 0
    -- Only show rows where the database math doesn't match reality
    AND ABS(CAST(total AS DECIMAL) - (CAST(quantity AS INT) * CAST(price AS DECIMAL))) > 0.01;

-- ====================================================================
-- STEP 8: Sequence Gap Analysis (Second Last)
-- Objective: Detect missing jumps in consecutive ID sequences.
-- ====================================================================
SELECT 
    current_id,
    next_id,
    (next_id - current_id - 1) AS missing_ids_count
FROM (
    SELECT 
        CAST(id AS INT) AS current_id,
        LEAD(CAST(id AS INT)) OVER (ORDER BY CAST(id AS INT)) AS next_id
    FROM sales100
) 
WHERE next_id IS NOT NULL 
  AND next_id - current_id > 1;

-- ====================================================================
-- STEP 9: Multi-Item Order Consistency Check (The Ultimate Audit)
-- Objective: Ensure that a single order_id never maps to multiple 
--            customers, dates, payment methods, or order statuses.
-- ====================================================================
SELECT 
    order_id,
    COUNT(DISTINCT customer_name) AS unique_customers,
    COUNT(DISTINCT order_date) AS unique_dates,
    COUNT(DISTINCT payment_method) AS unique_payments,
    COUNT(DISTINCT status) AS unique_statuses
FROM sales100
WHERE order_id IS NOT NULL AND TRIM(order_id) != ''
GROUP BY order_id
HAVING unique_customers > 1 
    OR unique_dates > 1 
    OR unique_payments > 1 
    OR unique_statuses > 1;
