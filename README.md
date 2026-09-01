# 📉 Customer Churn Root-Cause Analysis (SQL)
### End-to-End SQL Project | PostgreSQL • CTEs • Window Functions • Root-Cause Analysis

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-336791?style=flat&logo=postgresql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CTEs%20%7C%20Window%20Functions-blue)
![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=flat&logo=visualstudiocode&logoColor=white)

---

**Databel, a telecom provider, is losing 1,796 of 6,687 customers (26.9%) to churn — but nobody could say *which* segments were leaving or *why*.** This project answers that using SQL alone, no BI tool: a raw CSV is staged, normalized into a relational schema, and interrogated with analytical SQL until the drivers of churn — and the false leads — are both clearly identified.

---

## 🎯 The Problem

Retention teams can't act on "27% of customers churned." They need to know whether it's price, contract type, support experience, geography, or something else — and they need the hypotheses that *don't* hold up ruled out just as clearly as the ones that do, so budget doesn't get spent chasing the wrong lever.

## 🛠️ What I Did

| Step | Detail |
|---|---|
| 📥 Load | Loaded the raw 29-attribute Databel customer dataset into a PostgreSQL staging table |
| 🧩 Normalize | Split it into a 4-table relational schema (customers, accounts, usage, churn events) |
| 🧹 Clean | Handled two real data quality issues rather than dropping rows |
| 🔍 Analyze | Wrote CTEs and window functions to break churn down by contract type, payment method, spend, tenure, support contact frequency, and geography |
| 📐 Package | Built a root-cause view a retention team could query directly |

---

## 📦 Dataset

| | |
|---|---|
| **Source** | Databel telecom customer churn dataset (Maven Analytics) |
| **Size** | 6,687 customers · 29 raw attributes |
| **Covers** | Demographics, contract/billing, usage, churn outcome |
| **File** | `Datasets/Databel - Data.csv` |

---

## 🧩 Schema Design

The flat source file is normalized into four tables, all keyed on `customer_id`:

| Table | Grain | Contents |
|---|---|---|
| 👤 `customers` | 1 row / customer | demographics — gender, age, state, group |
| 💳 `accounts` | 1 row / customer | contract type, payment method, charges |
| 📶 `usage_stats` | 1 row / customer | call and data usage behavior |
| 🚪 `churn_events` | 1 row / customer | churn label, category, reason |

`accounts`, `usage_stats`, and `churn_events` each use `customer_id` as both primary key and a foreign key back to `customers`, enforcing a strict 1-to-1 relationship.

![ER Diagram](/Results/ERD_churn.pgerd.png)
![Schmema Design](/Results/normalized_data.png)

---

## 🧹 Data Cleaning Decisions

Two issues surfaced during the load, both handled to preserve rows rather than discard them:

- **`gender`** — widened from `VARCHAR(10)` to `VARCHAR(20)` after the initial load failed. The source data includes `"Prefer not to say"` (7 of 6,687 rows), which exceeded the original column width.
- **`intl_calls`** — 53 rows (0.8%) held non-integer values (e.g. `151.2`) in what should be a whole-number call count, likely a data export artifact. Rounded to the nearest integer instead of dropping the row or leaving a false decimal precision in place.

---

## 🔍 Key Findings

📄 **Contract type is the single strongest churn driver.** Month-to-Month customers churn at **46.3%**, vs. 11.3% for One-Year and just 2.8% for Two-Year — a 16x gap between the least and most committed segments.

🔄 **The device-protection hypothesis didn't hold up — and that's a finding in itself.** The starting assumption was that "Month-to-Month + no device protection" would be the highest-risk segment. The data says otherwise: customers *with* the device protection & online backup add-on churn at a *higher* rate than those without it, consistently across all three contract types (e.g. 49.0% vs. 45.5% within Month-to-Month). Contract length — not the protection add-on — is the real lever.

![Section4](/Results/section%204.png)

💵 **Payment method is a strong secondary signal.** Paper Check customers churn at 38.0%, more than 2.5x the rate of Credit Card customers (14.5%).

💰 **The company is disproportionately losing its highest-value customers.** Churn rises steadily with monthly charge — from 11.2% in the cheapest quartile to 37.3% in the priciest.

☎️ **Support friction precedes churn.** Churned customers averaged 2.4 customer service calls vs. 0.37 for retained customers — roughly 6.5x.

⏳ **Churn is front-loaded.** 20% of all churn (367 of 1,796 customers) happens within the first month, and over half (992) churn within the first year — retention efforts matter most early in the lifecycle.

🏃 **Competitor switching is the top stated reason for leaving** (805 of 1,769 categorized churns, 44.8%), concentrated heavily in Month-to-Month accounts.

📍 **California is a geographic outlier**, churning at 63.2% — nearly double the next-highest state (Ohio, 34.8%) — worth flagging for further investigation despite a moderate sample (68 customers).

---

## ✅ Recommendation

Two segments warrant different retention strategies:

- **Month-to-Month + Paper Check** customers churn at the highest *rate* (57.3%), suggesting payment friction compounds with low contract commitment — worth testing whether shifting this segment to autopay reduces churn.
- **Month-to-Month + Direct Debit** customers represent the highest *revenue exposure* ($31,383/month at risk, due to segment size), making them the priority for retention budget even at a slightly lower churn rate (53.9%).

Device protection bundling, the original hypothesis, showed no retention effect and is not recommended as a lever.

![Recommendation](/Results/high_risk_segment_summary.png)

---

## 📁 Project Structure

```
├── Datasets/
│   └── Databel - Data.csv          # raw source file
├── 01_create_staging.sql           # creates staging table, loads raw CSV
├── 02_normalize_schema.sql         # builds normalized schema, populates from staging
├── 03_analysis_queries.sql         # churn rate breakdowns, window functions, root-cause view
├── docs/
│   └── ERD.png                     # entity relationship diagram
├── results/
│   └── analysis_queries_result.csv # exported output of all analysis queries
└── README.md
```

---

## 🚀 How to Run

1. Create the database and run `01_create_staging.sql` to build the staging table and load the raw CSV. **Update the file path** in the `\copy` command to match where the CSV lives on your machine first.
2. Run `02_normalize_schema.sql` to build the four normalized tables and populate them from staging.
3. Run the verification block at the end of `02_normalize_schema.sql` — all four row counts should read 6687, and the sample join should return populated rows across all four tables.
4. Once verified, drop `staging_churn` — it's a working table only, not part of the final schema.
5. Run `03_analysis_queries.sql` section by section to reproduce every finding above, including the `high_risk_segment_summary` view.

---

## 📁 Skills Demonstrated

| Skill | Where Used |
|---|---|
| Relational schema design | 1 parent + 3 child tables with FK relationships, normalized from a flat source |
| Staging-table load pattern | Permissive `TEXT` staging table → typed inserts, isolating load errors from schema errors |
| SQL data cleaning | Column-width fix, decimal-artifact correction, both documented and preserved rather than dropped |
| CTEs | Used throughout Section 9–11 analysis for readable multi-step aggregation |
| Window functions | `RANK()` for state-level churn ranking, `NTILE()` for value-quartile analysis, running `SUM() OVER()` for cumulative tenure churn |
| Aggregate filtering | `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` pattern for conditional counts |
| Views | `high_risk_segment_summary` — a reusable object built directly from the confirmed findings |
| Root-cause framing | Explicitly tested and disproved a starting hypothesis rather than confirming it by default |

---

## 🧰 Tech Stack

PostgreSQL · SQL (CTEs, window functions) · VS Code