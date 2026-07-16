-- ====================================================================
-- PROJECT: DIRTY-TO-CLEAN SALES DATA PIPELINE
-- Phase 3: Data Cleaning, Validation & Transformation Operations
-- OBJECTIVE: Enforce strict schemas, eliminate duplicate IDs, 
--            standardize strings, repair timelines, and ensure math logic.
-- ====================================================================

-- ====================================================================
-- STEP 1: Define Clean Destination Schema
-- Objective: Enforce appropriate strict structural data types for 
--            all transactional features.
-- ====================================================================
DROP TABLE IF EXISTS sales100_clean;

CREATE TABLE sales100_clean (
    id INTEGER PRIMARY KEY,          -- Strict numeric primary key (blocks future duplicates)
    customer_name TEXT,
    order_id TEXT,                   -- Keeps text format for mixed string IDs
    order_date DATE,                 -- Enforces standard temporal structure
    product TEXT,
    category TEXT,
    quantity INTEGER,                -- Enforces integer restrictions
    price DECIMAL(10, 2),            -- Structured currency format
    payment_method TEXT,
    status TEXT,
    total DECIMAL(10, 2)             -- Structured currency format
);

-- ====================================================================
-- STEP 2: The Master Data Migration & Transformation
-- Objective: Migrate rows from dirty sales100 to sales100_clean,
--            deduplicating IDs, fixing dates, and standardizing text.
-- ====================================================================
INSERT INTO sales100_clean (
    id, customer_name, order_id, order_date, product, 
    category, quantity, price, payment_method, status, total
)
SELECT 
    CAST(id AS INTEGER),
    TRIM(customer_name),
    TRIM(order_id),
    
    -- Fix Date Formats: Standardize everything to YYYY-MM-DD
    CASE 
        -- If it's already in YYYY-MM-DD, just pass it through
        WHEN order_date LIKE '____-__-__' THEN order_date
        -- If it's in MM/DD/YYYY format, restructure it into YYYY-MM-DD
        WHEN order_date LIKE '__/__/____' THEN 
             SUBSTR(order_date, 7, 4) || '-' || SUBSTR(order_date, 1, 2) || '-' || SUBSTR(order_date, 4, 2)
        ELSE NULL -- Set corrupt/unparseable text as NULL to fix later
    END AS order_date,
    
    -- Standardize text columns to uppercase to fix capitalization inconsistencies
    UPPER(TRIM(product)),
    UPPER(TRIM(category)),
    
    -- Cast metrics to their real numeric types
    CAST(quantity AS INTEGER),
    CAST(price AS DECIMAL(10, 2)),
    
    UPPER(TRIM(payment_method)),
    UPPER(TRIM(status)),
    CAST(total AS DECIMAL(10, 2))
FROM (
    -- Subquery assigns a row rank to catch duplicates
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY CAST(id AS INT) ORDER BY id) as rn
    FROM sales100
) 
WHERE rn = 1; -- Enforces that only the first unique instance of any ID is migrated!

-- ====================================================================
-- STEP 3: Verification Check Queries (Initial Migration)
-- Objective: Sanity check the final destination migration results.
--            (Keep these commented out in production files)
-- ====================================================================
-- SELECT COUNT(*) FROM sales100_clean;
-- SELECT id, COUNT(*) FROM sales100_clean WHERE id IN (142, 146, 175) GROUP BY id;

-- ====================================================================
-- STEP 4: Negative Metric Alignment & Financial Outlier Handling
-- Objective: Standardize negative quantities/totals as RETURNS, flip 
--            negative unit prices, and flag uncorrectable records.
-- ====================================================================

-- 1. If unit price is negative, it's a system typo. Flip it to positive absolute values.
UPDATE sales100_clean
SET price = ABS(price)
WHERE price < 0;

-- 2. If quantity is negative, logically classify the transaction status as a return.
--    Ensure the math balances: (Negative Quantity * Positive Price) = Negative Total
UPDATE sales100_clean
SET total = quantity * price,
    status = 'RETURN'
WHERE quantity < 0;

-- 3. Target check: Flag records with explicit zero elements that break business metrics
UPDATE sales100_clean
SET status = 'DATA_ERROR'
WHERE quantity = 0 OR price = 0;

-- ====================================================================
-- STEP 5: Financial Logic & Cross-Column Validation
-- Objective: Repair cross-column math discrepancies where metrics are valid,
--            but the database total is broken, drifting, or missing.
-- ====================================================================

-- 1. Mathematically calculate any total that migrated as a structural NULL
UPDATE sales100_clean
SET total = quantity * price
WHERE total IS NULL 
  AND quantity IS NOT NULL 
  AND price IS NOT NULL;

-- 2. Recalculate broken totals for positive sales if they drift from expected value
UPDATE sales100_clean
SET total = quantity * price
WHERE quantity > 0 
  AND price > 0 
  AND ABS(total - (quantity * price)) > 0.01;

-- 3. Catch-all: If total is still negative but quantity is positive, force recalculation
UPDATE sales100_clean
SET total = quantity * price
WHERE total < 0 AND quantity > 0;

-- ====================================================================
-- STEP 6: Targeted Temporal NULL Value Resolution
-- Objective: Flag records with unrepairable NULL dates and apply a standard
--            ISO placeholder to preserve database calculation chains.
-- ====================================================================
UPDATE sales100_clean
SET order_date = '1970-01-01',
    status = 'INVALID_DATE'
WHERE order_date IS NULL;

-- ====================================================================
-- STEP 7: Categorical Typo Realignment & Imputation
-- Objective: Resolve blank spaces (' '), literal 'NAN' text errors, and
--            standardize existing categorical variations based on product maps.
-- ====================================================================

-- 1. Clean up known trailing text variations to unified standards
UPDATE sales100_clean
SET category = 'ELECTRONICS'
WHERE category IN ('ELECTRONIC', 'ELEC', 'Electronics', 'Electronic', 'electronics', 'electronic');

-- 2. Conditional Imputation: Map completely empty or missing categories to their true context
UPDATE sales100_clean
SET category = CASE product
    WHEN 'HEADPHONE'  THEN 'ELECTRONICS'
    WHEN 'LAPTOP'     THEN 'ELECTRONICS'
    WHEN 'VACCUM'     THEN 'HOME APPLIANCES'
    WHEN 'BASKETBALL' THEN 'SPORTS'
    WHEN 'JEANS'      THEN 'CLOTHING'
    WHEN 'SHOES'      THEN 'CLOTHING'
    ELSE category 
END
WHERE TRIM(category) = '' OR category IS NULL;

-- 3. The 'NAN' Trapping Safehouse: Catch Python-exported text artifacts and map spelling typos
UPDATE sales100_clean
SET category = CASE 
    WHEN TRIM(product) IN ('BIOGRAPHY', 'BIOGHRAPHY') THEN 'BOOKS'
    WHEN TRIM(product) = 'SMARTPHONE'                 THEN 'ELECTRONICS'
    ELSE category 
END
WHERE UPPER(TRIM(category)) = 'NAN';
