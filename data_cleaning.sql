-- ====================================================================
-- STEP 1: Define Clean Destination Schema
-- Objective: Enforce appropriate strict structural data types for 
--            all transactional features.
-- ====================================================================

CREATE TABLE sales100_clean (
    id INTEGER PRIMARY KEY,          -- Strict numeric primary key
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
-- STEP 3: Verification Check Queries
-- Objective: Sanity check the final destination migration results.
-- ====================================================================

-- Check overall records successfully migrated
 SELECT COUNT(*)
 FROM sales100_clean;

-- Validate targeted deduplication of IDs 142, 146, and 175
SELECT id, COUNT(*) 
FROM sales100_clean 
WHERE id IN (142, 146, 175) GROUP BY id;

-- ====================================================================
-- STEP 4: Financial Logic Corrections & Outlier Handling
-- Objective: Repair cross-column math discrepancies where quantity and 
--            price are valid, but the total is broken or negative.
-- ====================================================================

-- 1. Recalculate broken totals using valid quantity and price metrics
UPDATE sales100_clean
SET total = quantity * price
WHERE quantity > 0 
  AND price > 0 
  AND ABS(total - (quantity * price)) > 0.01;

-- 2. Target check: Nullify or flags records with zero/negative items 
--    that cannot be mathematically corrected without external context.
UPDATE sales100_clean
SET status = 'DATA_ERROR'
WHERE quantity <= 0 
   OR price <= 0;

-- ====================================================================
-- STEP 5: Categorical Typo Realignment
-- Objective: Map residual typos or variants to unified naming standards.
-- ====================================================================

-- Example path for category structural alignment (adjust based on your actual data typos)
UPDATE sales100_clean
SET category = 'ELECTRONICS'
WHERE category IN ('ELECTRONICS', 'ELECTRONIC' , 'ELEC', 'Electronics', 'Electronic', 'electronics', 'electronic' );

-- ====================================================================
-- STEP 4: Targeted NULL Value Resolution
-- Objective: Repair missing totals using calculation logic and handle
--            corrupt or unparseable dates.
-- ====================================================================

-- 1. Mathematically calculate any total that is currently NULL
UPDATE sales100_clean
SET total = quantity * price
WHERE total IS NULL 
  AND quantity IS NOT NULL 
  AND price IS NOT NULL;

-- 2. Flag records with unrepairable NULL dates and apply a placeholder
UPDATE sales100_clean
SET order_date = '1970-01-01',
    status = 'INVALID_DATE'
WHERE order_date IS NULL;


-- ====================================================================
-- STEP 5: Negative Metric Alignment & Financial Flagging
-- Objective: Standardize negative quantities/totals as REFUNDS and 
--            ensure the absolute math remains clean.
-- ====================================================================

-- 1. If price is negative, it's almost always a system error. Flip it to positive.
UPDATE sales100_clean
SET price = ABS(price)
WHERE price < 0;

-- 2. If quantity is negative, treat it as a return. 
--    Ensure the total matches: (Negative Quantity * Positive Price) = Negative Total
UPDATE sales100_clean
SET total = quantity * price,
    status = 'RETURN'
WHERE quantity < 0;

-- 3. Catch-all: If total is still negative but quantity is positive, recalculate it properly
UPDATE sales100_clean
SET total = quantity * price
WHERE total < 0 AND quantity > 0;

-- ====================================================================
-- STEP 6: Conditional Category Imputation
-- Objective: Resolve blank spaces (' ') and NULLs in categories by
--            mapping them directly to their corresponding products.
-- ====================================================================

UPDATE sales100_clean
SET category = CASE product
    WHEN 'HEADPHONE'  THEN 'ELECTRONICS'
    WHEN 'LAPTOP'     THEN 'ELECTRONICS'
    WHEN 'VACCUM'     THEN 'HOME APPLIANCES'
    WHEN 'BASKETBALL' THEN 'SPORTS'
    WHEN 'JEANS'      THEN 'CLOTHING'
    WHEN 'SHOES'      THEN 'CLOTHING'
    ELSE category -- Keep the original value if it doesn't match our target list
END
WHERE TRIM(category) = '' OR category IS NULL;

-- ====================================================================
-- STEP 7: Resolution of 'NAN' Values in Categorical Features
-- Objective: Map residual text 'NAN' strings to their true categories
--            based on distinct structural product mappings.
-- ====================================================================

UPDATE sales100_clean
SET category = CASE product
    WHEN 'BIOGRAPHY'  THEN 'BOOKS'
    WHEN 'SMARTPHONE' THEN 'ELECTRONICS'
    ELSE category 
END
WHERE UPPER(TRIM(category)) = 'NAN';
