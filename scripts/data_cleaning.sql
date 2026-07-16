-- ====================================================================
-- PROJECT: DIRTY-TO-CLEAN SALES DATA PIPELINE
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
-- STEP 2: The Master Data Migration, Ingestion & Mixed Date Parsing
-- Objective: Migrate rows from raw table while simultaneously deduplicating IDs,
--            standardizing text cases, and resolving dynamic date patterns.
-- ====================================================================
INSERT INTO sales100_clean (
    id, customer_name, order_id, order_date, product, 
    category, quantity, price, payment_method, status, total
)
SELECT 
    CAST(id AS INTEGER),
    TRIM(customer_name),
    TRIM(order_id),
    
    -- AIRTIGHT MIXED DATE PARSER: Resolves YYYY-MM-DD, MM/DD/YYYY, and single-digit variations
    CASE 
        -- Ignore text artifacts completely ('abc')
        WHEN order_date = 'abc' THEN NULL

        -- Format A: Year is at the front (e.g., 2025/07/24 or 2025-7-24)
        WHEN REPLACE(order_date, '/', '-') LIKE '____-%' 
            THEN DATE(REPLACE(order_date, '/', '-'))
            
        -- Format B: Month/Day is at the front, ending in a 4-digit Year (e.g., 7/24/2025 or 07-24-2025)
        WHEN REPLACE(order_date, '/', '-') LIKE '%-____' 
            THEN DATE(
                SUBSTR(REPLACE(order_date, '/', '-'), -4) || '-' || -- Year
                PRINTF('%02d', CAST(REPLACE(order_date, '/', '-') AS INT)) || '-' || -- Month
                PRINTF('%02d', CAST(SUBSTR(REPLACE(order_date, '/', '-'), INSTR(REPLACE(order_date, '/', '-'), '-') + 1) AS INT)) -- Day
            )
        ELSE NULL 
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
    -- Subquery assigns a row rank to drop structural duplicates
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY CAST(id AS INT) ORDER BY id) as rn
    FROM sales100
) 
WHERE rn = 1;

-- ====================================================================
-- STEP 3: Negative Metric Alignment & Financial Outlier Handling
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
-- STEP 4: Financial Logic & Cross-Column Validation
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
-- STEP 5: Temporal Boundary & Error Isolation
-- Objective: Flag records with unrepairable text dates ('abc') with a standard
--            ISO placeholder to preserve database execution chains.
-- ====================================================================
UPDATE sales100_clean
SET order_date = '1970-01-01',
    status = 'INVALID_DATE'
WHERE order_date IS NULL;

-- ====================================================================
-- STEP 6: Categorical Typo Realignment & Imputation
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
