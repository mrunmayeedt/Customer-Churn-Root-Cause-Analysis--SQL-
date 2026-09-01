CREATE DATABASE churn_db;

DROP TABLE IF EXISTS staging_churn;

CREATE TABLE staging_churn (
    customer_id                     TEXT,
    churn_label                     TEXT,
    account_length_months           TEXT,
    local_calls                     TEXT,
    local_mins                      TEXT,
    intl_calls                      TEXT,
    intl_mins                       TEXT,
    intl_active                     TEXT,
    intl_plan                       TEXT,
    extra_intl_charges              TEXT,
    customer_service_calls          TEXT,
    avg_monthly_gb_download         TEXT,
    unlimited_data_plan             TEXT,
    extra_data_charges              TEXT,
    state                           TEXT,
    phone_number                    TEXT,
    gender                          TEXT,
    age                             TEXT,
    under_30                        TEXT,
    senior                          TEXT,
    cust_group                      TEXT,   -- "Group" is a reserved word, renamed
    number_in_group                 TEXT,
    device_protection_backup        TEXT,
    contract_type                   TEXT,
    payment_method                  TEXT,
    monthly_charge                  TEXT,
    total_charges                   TEXT,
    churn_category                  TEXT,
    churn_reason                    TEXT
);


-- \copy staging_churn FROM 'C:\Data_Analytics\Customer Churn Root-Cause Analysis (SQL)\Datasets\Databel - Data.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

SELECT COUNT(*) FROM staging_churn;