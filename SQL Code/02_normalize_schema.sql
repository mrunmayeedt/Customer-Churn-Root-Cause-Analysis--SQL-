- ============================================================
-- STEP 5: Build the normalized schema
-- ============================================================

DROP TABLE IF EXISTS churn_events CASCADE;
DROP TABLE IF EXISTS usage_stats CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;

-- Parent table: one row per customer, demographic facts only.
CREATE TABLE customers (
    customer_id         VARCHAR(15) PRIMARY KEY,
    phone_number         VARCHAR(20),
    gender               VARCHAR(10),
    age                  SMALLINT,
    under_30             BOOLEAN,
    senior               BOOLEAN,
    state                CHAR(2),
    cust_group           BOOLEAN,
    number_in_group      SMALLINT
);

-- Account / contract facts — one row per customer.
CREATE TABLE accounts (
    customer_id               VARCHAR(15) PRIMARY KEY
                               REFERENCES customers(customer_id),
    account_length_months     SMALLINT,
    contract_type              VARCHAR(20),
    payment_method              VARCHAR(20),
    monthly_charge               NUMERIC(8,2),
    total_charges                NUMERIC(10,2),
    unlimited_data_plan          BOOLEAN,
    device_protection_backup     BOOLEAN
);

-- Usage facts — one row per customer, everything call/data related.
CREATE TABLE usage_stats (
    customer_id               VARCHAR(15) PRIMARY KEY
                               REFERENCES customers(customer_id),
    local_calls                SMALLINT,
    local_mins                 NUMERIC(8,1),
    intl_calls                 SMALLINT,
    intl_mins                  NUMERIC(8,1),
    intl_active                 BOOLEAN,
    intl_plan                   BOOLEAN,
    extra_intl_charges          NUMERIC(8,2),
    customer_service_calls      SMALLINT,
    avg_monthly_gb_download     SMALLINT,
    extra_data_charges          NUMERIC(8,2)
);

-- Churn outcome — one row per customer (nullable category/reason
-- for the ~4,918 customers who haven't churned).
CREATE TABLE churn_events (
    customer_id       VARCHAR(15) PRIMARY KEY
                       REFERENCES customers(customer_id),
    churn_label       BOOLEAN,
    churn_category    VARCHAR(30),
    churn_reason      TEXT
);
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';


-- ============================================================
-- STEP 6: Populate normalized tables from staging
-- (order matters — customers first, since the others FK into it)
-- ============================================================
ALTER TABLE customers ALTER COLUMN gender TYPE VARCHAR(20); -- earlier gave error as value too long for type character varying(10), so fixing by altering table

INSERT INTO customers (customer_id, phone_number, gender, age, under_30,
                        senior, state, cust_group, number_in_group)
SELECT
    customer_id,
    phone_number,
    gender,
    NULLIF(age, '')::SMALLINT,
    (under_30 = 'Yes'),
    (senior = 'Yes'),
    state,
    (cust_group = 'Yes'),
    NULLIF(number_in_group, '')::SMALLINT
FROM staging_churn;

INSERT INTO accounts (customer_id, account_length_months, contract_type,
                       payment_method, monthly_charge, total_charges,
                       unlimited_data_plan, device_protection_backup)
SELECT
    customer_id,
    NULLIF(account_length_months, '')::SMALLINT,
    contract_type,
    payment_method,
    NULLIF(monthly_charge, '')::NUMERIC(8,2),
    NULLIF(total_charges, '')::NUMERIC(10,2),
    (unlimited_data_plan = 'Yes'),
    (device_protection_backup = 'Yes')
FROM staging_churn;

INSERT INTO usage_stats (customer_id, local_calls, local_mins, intl_calls,
                          intl_mins, intl_active, intl_plan,
                          extra_intl_charges, customer_service_calls,
                          avg_monthly_gb_download, extra_data_charges)
SELECT
    customer_id,
    NULLIF(local_calls, '')::SMALLINT,
    NULLIF(local_mins, '')::NUMERIC(8,1),
    ROUND(NULLIF(intl_calls, '')::NUMERIC)::SMALLINT AS intl_calls,
    NULLIF(intl_mins, '')::NUMERIC(8,1),
    (intl_active = 'Yes'),
    (LOWER(intl_plan) = 'yes'),
    NULLIF(extra_intl_charges, '')::NUMERIC(8,2),
    NULLIF(customer_service_calls, '')::SMALLINT,
    NULLIF(avg_monthly_gb_download, '')::SMALLINT,
    NULLIF(extra_data_charges, '')::NUMERIC(8,2)
FROM staging_churn;

INSERT INTO churn_events (customer_id, churn_label, churn_category, churn_reason)
SELECT
    customer_id,
    (churn_label = 'Yes'),
    NULLIF(churn_category, ''),
    NULLIF(churn_reason, '')
FROM staging_churn;

 SELECT
    (SELECT COUNT(*) FROM customers)     AS customers_n,
   (SELECT COUNT(*) FROM accounts)      AS accounts_n,
    (SELECT COUNT(*) FROM usage_stats)   AS usage_n,
   (SELECT COUNT(*) FROM churn_events)  AS churn_n;

SELECT c.customer_id, c.state, a.contract_type, u.local_mins, ch.churn_label
FROM customers c
JOIN accounts a USING (customer_id)
JOIN usage_stats u USING (customer_id)
JOIN churn_events ch USING (customer_id)
LIMIT 10;


DROP TABLE staging_churn;