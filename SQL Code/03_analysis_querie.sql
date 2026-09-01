-- ============================================================
-- Customer Churn Root-Cause Analysis (SQL)
-- 03_analysis_queries.sql
-- Core business queries + window functions, run after
-- 02_normalize_schema.sql and dropping staging_churn.
-- ============================================================


-- ============================================================
-- SECTION 1: Baseline — overall churn rate
-- ============================================================

SELECT
    SUM(CASE WHEN churn_label THEN 1 ELSE 0 END) AS churned,
    COUNT(*)                                     AS total,
    ROUND(
        100.0 * SUM(CASE WHEN churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS churn_rate_pct
FROM churn_events;


-- ============================================================
-- SECTION 2: Churn rate by contract type
-- Hypothesis from earlier: Month-to-Month drives most churn
-- ============================================================

SELECT
    a.contract_type,
    COUNT(*)                                              AS customers,
    SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END)       AS churned,
    ROUND(
        100.0 * SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS churn_rate_pct
FROM accounts a
JOIN churn_events ch USING (customer_id)
GROUP BY a.contract_type
ORDER BY churn_rate_pct DESC;


-- ============================================================
-- SECTION 3: Churn rate by payment method
-- ============================================================

SELECT
    a.payment_method,
    COUNT(*)                                              AS customers,
    SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END)       AS churned,
    ROUND(
        100.0 * SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS churn_rate_pct
FROM accounts a
JOIN churn_events ch USING (customer_id)
GROUP BY a.payment_method
ORDER BY churn_rate_pct DESC;


-- ============================================================
-- SECTION 4: Churn rate by contract type AND device protection
-- This is the interaction that tests the specific root-cause
-- hypothesis: M2M + no protection is the highest-risk segment
-- ============================================================

SELECT
    a.contract_type,
    a.device_protection_backup,
    COUNT(*)                                              AS customers,
    SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END)       AS churned,
    ROUND(
        100.0 * SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS churn_rate_pct
FROM accounts a
JOIN churn_events ch USING (customer_id)
GROUP BY a.contract_type, a.device_protection_backup
ORDER BY churn_rate_pct DESC;


-- ============================================================
-- SECTION 5: Why are they leaving? Churn category breakdown
-- (only churned customers have a category — WHERE excludes NULLs)
-- ============================================================

SELECT
    churn_category,
    COUNT(*) AS churned_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_churn
FROM churn_events
WHERE churn_label = TRUE
GROUP BY churn_category
ORDER BY churned_customers DESC;


-- ============================================================
-- SECTION 6: Does churn category differ by contract type?
-- e.g. do M2M customers leave for Price while Two-Year leave
-- for Competitor — different causes need different fixes
-- ============================================================

SELECT
    a.contract_type,
    ch.churn_category,
    COUNT(*) AS churned_customers
FROM accounts a
JOIN churn_events ch USING (customer_id)
WHERE ch.churn_label = TRUE
GROUP BY a.contract_type, ch.churn_category
ORDER BY a.contract_type, churned_customers DESC;


-- ============================================================
-- SECTION 7: Revenue at risk — monthly charge exposure among
-- customers who HAVEN'T churned yet, by risk segment
-- ============================================================

SELECT
    a.contract_type,
    a.device_protection_backup,
    COUNT(*)                          AS active_customers,
    ROUND(SUM(a.monthly_charge), 2)   AS monthly_revenue_at_risk
FROM accounts a
JOIN churn_events ch USING (customer_id)
WHERE ch.churn_label = FALSE
GROUP BY a.contract_type, a.device_protection_backup
ORDER BY monthly_revenue_at_risk DESC;


-- ============================================================
-- SECTION 8: Customer service calls vs churn
-- A classic churn signal — more support calls, more frustration
-- ============================================================

SELECT
    ch.churn_label,
    ROUND(AVG(u.customer_service_calls), 2) AS avg_service_calls
FROM usage_stats u
JOIN churn_events ch USING (customer_id)
GROUP BY ch.churn_label;


-- ============================================================
-- SECTION 9 (window functions): Rank states by churn rate
-- ============================================================

WITH state_churn AS (
    SELECT
        c.state,
        COUNT(*)                                            AS customers,
        SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END)     AS churned,
        ROUND(
            100.0 * SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
        ) AS churn_rate_pct
    FROM customers c
    JOIN churn_events ch USING (customer_id)
    GROUP BY c.state
    HAVING COUNT(*) >= 30   -- drop tiny-sample states, avoid noisy rates
)
SELECT
    state,
    customers,
    churn_rate_pct,
    RANK() OVER (ORDER BY churn_rate_pct DESC) AS churn_rank
FROM state_churn
ORDER BY churn_rank
LIMIT 10;


-- ============================================================
-- SECTION 10 (window functions): Monthly charge quartiles vs
-- churn rate — are you losing your highest-value customers?
-- ============================================================

WITH charge_quartiles AS (
    SELECT
        a.customer_id,
        a.monthly_charge,
        ch.churn_label,
        NTILE(4) OVER (ORDER BY a.monthly_charge) AS charge_quartile
    FROM accounts a
    JOIN churn_events ch USING (customer_id)
)
SELECT
    charge_quartile,
    COUNT(*)                                              AS customers,
    ROUND(MIN(monthly_charge), 2)                         AS min_charge,
    ROUND(MAX(monthly_charge), 2)                         AS max_charge,
    ROUND(
        100.0 * SUM(CASE WHEN churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS churn_rate_pct
FROM charge_quartiles
GROUP BY charge_quartile
ORDER BY charge_quartile;


-- ============================================================
-- SECTION 11 (window functions): Cumulative churn by tenure —
-- at what point in the customer lifecycle does risk peak?
-- ============================================================

WITH tenure_churn AS (
    SELECT
        a.account_length_months,
        SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END) AS churned_this_month
    FROM accounts a
    JOIN churn_events ch USING (customer_id)
    GROUP BY a.account_length_months
)
SELECT
    account_length_months,
    churned_this_month,
    SUM(churned_this_month) OVER (
        ORDER BY account_length_months
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_churned
FROM tenure_churn
ORDER BY account_length_months;


-- ============================================================
-- SECTION 12: Root-cause synthesis view
-- The single reusable object your README's headline finding
-- should be pulled from — turn this into CREATE VIEW once
-- you've confirmed which segment is the real driver above.
-- ============================================================

CREATE VIEW high_risk_segment_summary AS
SELECT
    a.contract_type,
    a.payment_method,
    COUNT(*)                                              AS customers,
    ROUND(
        100.0 * SUM(CASE WHEN ch.churn_label THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS churn_rate_pct,
    ROUND(SUM(CASE WHEN NOT ch.churn_label THEN a.monthly_charge ELSE 0 END), 2)
        AS monthly_revenue_at_risk
FROM accounts a
JOIN churn_events ch USING (customer_id)
GROUP BY a.contract_type, a.payment_method
ORDER BY churn_rate_pct DESC;

SELECT * FROM high_risk_segment_summary;