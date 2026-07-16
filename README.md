# 🔷 Project: Dirty-to-Clean Sales Data Pipeline

An end-to-end data engineering and business intelligence project. This pipeline takes highly volatile, "dirty" retail transaction logs, sanitizes them using programmatic SQL transformation scripts, and extracts high-value business insights to support executive decision-making.

---

## ⚡ Executive Insights & Key Findings (At a Glance)

> ### 💵 1. Core Financial Performance
> * **Gross Revenue Capacity:** **`$133,048.39`** (Top-line sales potential)
> * **Total Refund Outflow:** **`$22,957.65`** (Capital returned to customers)
> * **Realized Net Revenue:** **`$110,090.74`** (True, actual retained profit)
> * **Average Order Value (AOV):** **`$1,590.78`** per successful transaction
> * **Total Units Sold:** **`286` units** successfully moved
> * **Overall Return Rate:** Exceptionally healthy baseline at **`2.00%`**

> ### 🔍 2. Category & Portfolio Analysis
> * **The Electronics Return Bleed:** While global return rates are low, **`ELECTRONICS`** is a high-risk area. It generated **`$21,243.44`** in gross revenue but suffered **`$20,000.00`** in returns—meaning **94.15%** of its sales value was returned!
> * **High-Return Inventory Items:** **`BLENDER` (Electronics)** recorded a **`100.00%`** return rate, and **`T-SHIRT` (Clothing)** recorded a **`50.00%`** return rate on low initial volumes.
> * **Profit Dominance Index:** The business relies heavily on **`BOOKS`**, which single-handedly drives **`36.40%` ($40,073.31)** of all net revenue.

> ### 💳 3. Payment Methods & Customer Behavior
> * **High-Value Channel:** Customers paying via **`BANK TRANSFER`** spend the most per transaction with an AOV of **`$2,099.74`**.
> * **Return Correlation:** Orders processed via **`PAYPAL`** have the highest return probability (**`4.17%`**).

> ### 🛠️ 4. Data Engineering ROI ("Ghost Revenue")
> * **`$51,918.70` Rescued!** By successfully parsing chaotic, non-standard date formats (initially flagged as `INVALID_DATE`) rather than dropping the rows, this pipeline saved and restored over **$51k** in transactional reporting data for the business.
> * **Raw Data Ingestion Error Rate:** **`47.00%`** of incoming raw records contained duplicates, corrupt formats, or NULL values that this pipeline cleaned.

---

## 💻 Tech Stack & Architecture
* **Database Engine:** SQLite / PostgreSQL
* **Data Transformation:** SQL (Window Functions, Conditional Aggregations, CTEs)
* **Reporting:** Markdown / Git Version Control

---

## 📁 Repository Structure

Your project files are organized cleanly following industry best practices:

```text
├── data/
│   ├── messy_ecommerce_sales_data.csv  # Raw, volatile transaction logs
│   └── sales100_clean.csv              # Sanitized, analytical-ready database table
├── scripts/
│   ├── data_profiling.sql              # Initial data assessment and sanity checks
│   ├── data_cleaning.sql               # Core ETL cleaning script (deduplication, casting)
│   ├── eda_queries.sql                 # Baseline Business KPIs
│   └── advanced_insights.sql           # Complex analytics and risk profiling
└── README.md                           # Project documentation & insights
