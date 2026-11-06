-- Lesson 1.5: cost guardrails. Run once in Snowsight as ACCOUNTADMIN.
-- Resource monitors cover warehouse compute only, not serverless or AI (Cortex) usage.
-- Watch those on the trial balance page and with budgets.

USE ROLE ACCOUNTADMIN;

-- Trial warehouse, owned by ACCOUNTADMIN. Terraform does not manage it.
ALTER WAREHOUSE COMPUTE_WH SET
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;

CREATE OR REPLACE RESOURCE MONITOR LAB_MONITOR
  WITH CREDIT_QUOTA = 20            -- set below the trial credit balance; adjust if you ran a different value
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 80 PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE COMPUTE_WH SET RESOURCE_MONITOR = LAB_MONITOR;

-- Check: auto_suspend = 60 and resource_monitor = LAB_MONITOR.
SHOW WAREHOUSES LIKE 'COMPUTE_WH';
SHOW RESOURCE MONITORS;
