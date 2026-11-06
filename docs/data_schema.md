# Data schema

Draft for the lab. Source data is the Snowflake sample dataset `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1` (TPC-H, scale factor 1, about 0.26 GB). It is read-only and shared; dbt builds everything else in our own database.

Use `TPCH_SF1` only. `TPCH_SF1000` is about 278 GB and would burn trial credits.

## Source tables

| Table | Rows | Columns used |
|-------|------|--------------|
| `REGION` | 5 | `R_REGIONKEY`, `R_NAME` |
| `NATION` | 25 | `N_NATIONKEY`, `N_NAME`, `N_REGIONKEY` |
| `CUSTOMER` | 150,000 | `C_CUSTKEY`, `C_NAME`, `C_NATIONKEY`, `C_PHONE`, `C_ACCTBAL`, `C_MKTSEGMENT` |
| `ORDERS` | 1,500,000 | `O_ORDERKEY`, `O_CUSTKEY`, `O_ORDERSTATUS`, `O_TOTALPRICE`, `O_ORDERDATE`, `O_ORDERPRIORITY` |
| `SUPPLIER` | 10,000 | `S_SUPPKEY`, `S_NAME`, `S_NATIONKEY`, `S_PHONE`, `S_ACCTBAL` |

Not used: `LINEITEM`, `PART`, `PARTSUPP`.

Types: keys and balances are `NUMBER`, names, phones and segments are `TEXT`, order date is `DATE`.

`C_MKTSEGMENT` values: `AUTOMOBILE`, `BUILDING`, `FURNITURE`, `HOUSEHOLD`, `MACHINERY`.

Regions: `AFRICA`, `AMERICA`, `ASIA`, `EUROPE`, `MIDDLE EAST`. Nations: 25 countries, each in one region.

## Join paths

```
REGION.R_REGIONKEY   <- NATION.N_REGIONKEY
NATION.N_NATIONKEY   <- CUSTOMER.C_NATIONKEY
NATION.N_NATIONKEY   <- SUPPLIER.S_NATIONKEY
CUSTOMER.C_CUSTKEY   <- ORDERS.O_CUSTKEY
```

## Our database

Database `ANALYTICS` (name is a suggestion), built by dbt as `SVC_DBT` with role `TRANSFORMER`.

| Schema | Purpose |
|--------|---------|
| `STAGING` | Renamed, typed copies of the source tables |
| `MARTS` | Tables analysts query; row access, masking and aggregation policies attach here |
| `GOVERNANCE` | Policy objects themselves (suggested; confirm in lesson 6.1) |

## Staging models

`STG_REGION`, `STG_NATION`, `STG_CUSTOMER`, `STG_ORDERS`, `STG_SUPPLIER`. One per source table, no business logic.

## Mart models

Names are resolved in dbt so policies never have to join.

### `DIM_NATION`

| Column | Source |
|--------|--------|
| `NATION_KEY` | `N_NATIONKEY` |
| `NATION_NAME` | `N_NAME` |
| `REGION_NAME` | `R_NAME` via `N_REGIONKEY` |

### `DIM_CUSTOMER`

| Column | Source |
|--------|--------|
| `CUSTOMER_KEY` | `C_CUSTKEY` |
| `CUSTOMER_NAME` | `C_NAME` |
| `NATION_NAME` | `N_NAME` via `C_NATIONKEY` |
| `REGION_NAME` | `R_NAME` via nation |
| `MARKET_SEGMENT` | `C_MKTSEGMENT` |
| `PHONE` | `C_PHONE` |
| `ACCOUNT_BALANCE` | `C_ACCTBAL` |

### `FCT_ORDERS`

| Column | Source |
|--------|--------|
| `ORDER_KEY` | `O_ORDERKEY` |
| `CUSTOMER_KEY` | `O_CUSTKEY` |
| `ORDER_DATE` | `O_ORDERDATE` |
| `ORDER_STATUS` | `O_ORDERSTATUS` |
| `ORDER_PRIORITY` | `O_ORDERPRIORITY` |
| `TOTAL_PRICE` | `O_TOTALPRICE` |
| `CUSTOMER_NATION` | nation of the customer |
| `CUSTOMER_REGION` | region of the customer |
| `CUSTOMER_SEGMENT` | `C_MKTSEGMENT` |

### `DIM_SUPPLIER`

| Column | Source |
|--------|--------|
| `SUPPLIER_KEY` | `S_SUPPKEY` |
| `SUPPLIER_NAME` | `S_NAME` |
| `NATION_NAME` | `N_NAME` via `S_NATIONKEY` |
| `PHONE` | `S_PHONE` |
| `ACCOUNT_BALANCE` | `S_ACCTBAL` |

### `AGG_ORDERS_GEO`

Pre-aggregated for the `GLOBAL_LEADER` role. One row per region and nation; no customer-level columns.

| Column | Source |
|--------|--------|
| `REGION_NAME` | `FCT_ORDERS.CUSTOMER_REGION` |
| `NATION_NAME` | `FCT_ORDERS.CUSTOMER_NATION` |
| `ORDER_COUNT` | count of orders |
| `TOTAL_PRICE` | sum of `TOTAL_PRICE` |
| `AVG_ORDER_PRICE` | average of `TOTAL_PRICE` |
| `CUSTOMER_COUNT` | distinct `CUSTOMER_KEY` |

## Where policies attach

| Lesson | Policy | Target |
|--------|--------|--------|
| 6.1 | Row access `RAP_REGION` | `DIM_NATION.REGION_NAME` |
| 6.2 | Row access `RAP_REGION_SEGMENT` (two arguments) | `DIM_CUSTOMER` and `FCT_ORDERS` (region and segment columns) |
| 6.5 | Masking | `DIM_CUSTOMER.PHONE`, visible only to `PII_READER` |
| 6.5 | Masking `MASK_CUSTOMER_NAME` | `DIM_CUSTOMER.CUSTOMER_NAME`, masked for `BRAND_TEAM_*` |
| 6.6 | Conditional masking | `DIM_SUPPLIER` (no row access policy on this table) |
| 6.7 | Tag-based masking, `PII` tag | STRING and NUMBER policies; tag base columns such as `PHONE` and `ACCOUNT_BALANCE` |
| 6.8 | Aggregation, `MIN_GROUP_SIZE => 5` | `FCT_ORDERS` and `AGG_ORDERS_GEO` (the only table `GLOBAL_LEADER` can read) |

A table carries only one row access policy, so country-level access (for example Germany only) extends `RAP_REGION_SEGMENT` with a nation argument and does not add a second policy.

A column cannot be in both a row access policy signature and a masking policy signature.

## Semantic layer

`SALES` semantic view (lesson 3.4) over `FCT_ORDERS` and the dimensions. Tag it `semantic` so Airflow skips it (lesson 4.3).

## To confirm when building

- Exact database and schema names.
- Whether policy objects live in `ANALYTICS.GOVERNANCE` or elsewhere.
- Column names above are proposals; adjust in dbt and keep this file in step.
