# 📊 Project: Dirty-to-Clean Sales Data Pipeline

## 📌 Project Overview
Data is almost never clean in the real world. In this project, taking a messy, real-world dataset containing over 100 simulated e-commerce transaction logs of unformatted e-commerce sales records and built an end-to-end pipeline to scrub, restructure, and validate it. 

By applying rigorous data-cleaning workflows, I transformed a corrupted spreadsheet into a reliable, relational database ready for business intelligence (BI) modeling and analytics.

## 🛠️ Tech Stack & Tools Used
* **SQL (MySQL):** Used for heavy-lifting data aggregation, identifying structural duplicates, and filtering text patterns.
* **GitHub Desktop:** For version control and maintaining clean, documented project snapshots.

## 📐 Data Pipeline Architecture
The workflow chart below illustrates how data flows from its initial unorganized state, through validation check-points, and finally into production-ready storage:

## 🚨 The Problems Identified (and How I Fixed Them)
Through initial data profiling, I identified four critical bottlenecks that would break any analytics dashboard:

### 1. The Duplicate Row Dilemma
* **The Mess:** The same transaction IDs appeared multiple times due to a software logging bug, artificially inflating revenue data.
* **The Fix:** Used SQL self-joins and window functions to isolate unique purchase events and drop ghost duplicates.

### 2. Corrupted Text Formatting
* **The Mess:** Customer text entries had broken string spacing and inconsistent casing (e.g., `  jOe smITh  `, `JOE SMITH`).
* **The Fix:** Applied dynamic string manipulation (`TRIM`, `LOWER`, and uppercase capitalization functions) to perfectly standardize thousands of customer profiles.

### 3. Invalid Contact Formatting (Regex Challenge)
* **The Mess:** The database accepted invalid e-mail address inputs that did not match structural criteria (e.g., missing domains, uppercase `.COM` suffixes, symbols in usernames).
* **The Fix:** Implemented rigid Regular Expression (`REGEXP BINARY`) patterns to flag and isolate faulty records.

### 4. Missing Numerical Records
* **The Mess:** Crucial numeric entries like sales figures and product keys were empty or null.
* **The Fix:** Programmed fallback constraints using conditional logic to impute missing numbers without skewing data distributions.
