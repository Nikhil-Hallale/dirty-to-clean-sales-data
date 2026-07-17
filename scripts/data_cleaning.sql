
-- #######################################################################
-- PART 2: CLEANING
-- #######################################################################
-- creatin new table so that the raw is safe
DROP TABLE IF EXISTS sales100_clean;

CREATE TABLE sales100_clean (
    id INTEGER PRIMARY KEY,
    customer_name TEXT,
    order_id TEXT,
    order_date DATE,
    product TEXT,
    category TEXT,
    quantity INTEGER,
    price DECIMAL(10, 2),
    payment_method TEXT,
    status TEXT,
    total DECIMAL(10, 2),
    data_quality_note TEXT         
);

--inserting values from the raw table into the new table
INSERT INTO sales100_clean (
    id, customer_name, order_id, order_date, product,
    category, quantity, price, payment_method, status, total
)
SELECT
    CAST(id AS INTEGER),
    TRIM(customer_name),
    TRIM(order_id),

-- handling date related issues 
    CASE
        WHEN order_date GLOB '*[a-zA-Z]*' THEN NULL
        WHEN REPLACE(order_date, '/', '-') LIKE '____-%'
            THEN DATE(REPLACE(order_date, '/', '-'))
        WHEN REPLACE(order_date, '/', '-') LIKE '%-____'
            THEN DATE(
                SUBSTR(REPLACE(order_date, '/', '-'), -4) || '-' ||
                PRINTF('%02d', CAST(REPLACE(order_date, '/', '-') AS INT)) || '-' ||
                PRINTF('%02d', CAST(SUBSTR(REPLACE(order_date, '/', '-'), INSTR(REPLACE(order_date, '/', '-'), '-') + 1) AS INT))
            )
        ELSE NULL
    END AS order_date,

    UPPER(TRIM(product)),
    UPPER(TRIM(category)),

    CASE WHEN REPLACE(TRIM(quantity), '-', '') GLOB '[0-9]*'
              AND TRIM(quantity) NOT GLOB '*[a-zA-Z]*'
         THEN CAST(quantity AS INTEGER)
         ELSE NULL END,


    CASE WHEN REPLACE(REPLACE(REPLACE(TRIM(price), '$',''), ',', ''), '-','') GLOB '[0-9]*'
         THEN CAST(REPLACE(REPLACE(price, '$',''), ',', '') AS DECIMAL(10,2))
         ELSE NULL END,

    UPPER(TRIM(payment_method)),
    UPPER(TRIM(status)),
    CAST(total AS DECIMAL(10, 2))
FROM (
 
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY CAST(id AS INT) ORDER BY id) AS rn
    FROM sales100
)
WHERE rn = 1;

--  Negative-value handling
UPDATE sales100_clean
SET price = ABS(price)
WHERE price < 0;

UPDATE sales100_clean
SET total = quantity * price,
    status = 'RETURNED'
WHERE quantity < 0;


UPDATE sales100_clean
SET status = 'DATA_ERROR'
WHERE quantity IS NULL OR price IS NULL OR quantity = 0 OR price = 0;

-- Financial cross-column repairs 
UPDATE sales100_clean
SET total = quantity * price
WHERE total IS NULL AND quantity IS NOT NULL AND price IS NOT NULL;

UPDATE sales100_clean
SET total = quantity * price
WHERE quantity > 0 AND price > 0
  AND ABS(total - (quantity * price)) > 0.01;

UPDATE sales100_clean
SET total = quantity * price
WHERE total < 0 AND quantity > 0;

-- Temporal boundary isolation 
UPDATE sales100_clean
SET order_date = '1970-01-01',
    status = 'INVALID_DATE'
WHERE order_date IS NULL;

--  Category standardization
UPDATE sales100_clean
SET category = 'ELECTRONICS'
WHERE category IN ('ELECTRONIC', 'ELEC');

WITH canonical AS (
    SELECT product, category, COUNT(*) AS n,
           ROW_NUMBER() OVER (PARTITION BY product ORDER BY COUNT(*) DESC) AS rnk
    FROM sales100_clean
    WHERE category IS NOT NULL AND TRIM(category) <> '' AND UPPER(category) <> 'NAN'
    GROUP BY product, category
)
UPDATE sales100_clean
SET category = (
    SELECT category FROM canonical
    WHERE canonical.product = sales100_clean.product AND rnk = 1
)
WHERE product IN (SELECT product FROM canonical);

-- giving category to the products that didn't one earlier
UPDATE sales100_clean
SET category = CASE product
    WHEN 'HEADPHONES'  THEN 'ELECTRONICS'
    WHEN 'LAPTOP'      THEN 'ELECTRONICS'
    WHEN 'VACUUM'      THEN 'HOME'
    WHEN 'BASKETBALL'  THEN 'SPORTS'
    WHEN 'JEANS'       THEN 'CLOTHING'
    WHEN 'SHOES'       THEN 'CLOTHING'
    WHEN 'BIOGRAPHY'   THEN 'BOOKS'
    WHEN 'SMARTPHONE'  THEN 'ELECTRONICS'
    ELSE 'UNASSIGNED'
END
WHERE category IS NULL OR TRIM(category) = '' OR UPPER(category) = 'NAN';

--  Outlier flagging
WITH cat_avg AS (
    SELECT category, AVG(price) AS avg_price
    FROM sales100_clean
    WHERE status NOT IN ('DATA_ERROR', 'INVALID_DATE')
    GROUP BY category
)
UPDATE sales100_clean
SET data_quality_note = 'PRICE_OUTLIER_REVIEW: price is ' ||
    ROUND(sales100_clean.price / cat_avg.avg_price, 1) || 'x the category average'
FROM cat_avg
WHERE sales100_clean.category = cat_avg.category
  AND sales100_clean.price > 3 * cat_avg.avg_price
  AND sales100_clean.status NOT IN ('DATA_ERROR', 'INVALID_DATE');
