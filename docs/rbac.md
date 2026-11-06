# RBAC design (draft)

Lesson 1.3. Nothing here exists in Snowflake yet; Terraform creates it in Phase 2. Role and object names are suggestions. If you rename one, update the diagram and tables together.

See [data_schema.md](data_schema.md) for the objects the roles reach.

## Principles

- **Access roles** hold object privileges on one set of objects. No users or jobs are granted to them directly.
- **Functional roles** map to a job (analyst, dbt, deployer). They inherit access roles and carry no object privileges of their own, except ownership where noted.
- **System roles** (`SYSADMIN`) sit on top. The top functional roles are granted to `SYSADMIN`, so it can see everything it manages. `ACCOUNTADMIN` is used only when a step needs it, such as the resource monitor in 1.5.
- **Service users** (`TYPE = SERVICE`) log in with a key pair and one default functional role each.
- **Row-level access by region or country is not done with roles.** One policy per table filters rows, and an entitlements mapping says which role sees which regions. See [data_schema.md](data_schema.md#where-policies-attach).

## Hierarchy

Read it bottom up: a user holds a functional role, which inherits access roles.

```
SYSADMIN
 ├── TRANSFORMER ──────────┬── AR_SAMPLE_DATA_READ
 │    (owns STAGING,       └── AR_WH_USE
 │     MARTS)
 ├── ANALYST_EU ───────────┬── AR_MARTS_READ
 ├── ANALYST_US ───────────┤   AR_WH_USE
 ├── ANALYST_GLOBAL ───────┤
 ├── PII_READER ───────────┤
 ├── BRAND_TEAM_EU ────────┤   (customer name masked)
 ├── BRAND_TEAM_US ────────┤
 ├── BRAND_TEAM_GLOBAL ────┘
 ├── GLOBAL_LEADER ────────┬── AR_MARTS_AGG_READ
 │                         └── AR_WH_USE
 ├── RAP_ADMIN ────────────┬── AR_MARTS_READ
 │                         ├── AR_GOVERNANCE_APPLY
 │                         └── AR_WH_USE
 └── TF_ADMIN              (created by hand in 1.4; creates roles,
                            databases, warehouses and grants)
```

## Access roles

| Role | Privileges |
|------|------------|
| `AR_SAMPLE_DATA_READ` | `IMPORTED PRIVILEGES` on `SNOWFLAKE_SAMPLE_DATA` |
| `AR_MARTS_READ` | `USAGE` on `ANALYTICS` and `ANALYTICS.MARTS`; `SELECT` on current and future tables and views in `MARTS` |
| `AR_MARTS_AGG_READ` | `USAGE` on `ANALYTICS` and `ANALYTICS.MARTS`; `SELECT` on `AGG_ORDERS_GEO` only. No grant on `FCT_ORDERS`, `DIM_CUSTOMER` or any other table |
| `AR_GOVERNANCE_APPLY` | `USAGE` on `ANALYTICS.GOVERNANCE`; create and apply row access, masking and aggregation policies on `MARTS` tables |
| `AR_WH_USE` | `USAGE` on the lab warehouse (`XSMALL`, 60-second auto-suspend) |

## Functional roles

| Role | Job | Inherits | Also holds |
|------|-----|----------|------------|
| `TRANSFORMER` | dbt builds | `AR_SAMPLE_DATA_READ`, `AR_WH_USE` | Ownership of `ANALYTICS.STAGING` and `ANALYTICS.MARTS` (lesson 2.5) |
| `ANALYST_EU` | Europe analyst | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `ANALYST_US` | America analyst | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `ANALYST_GLOBAL` | All regions | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `PII_READER` | Sees unmasked phone numbers | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `BRAND_TEAM_EU` | Brand team, Europe. Sees customer rows but not customer names | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `BRAND_TEAM_US` | Brand team, America. Same masking | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `BRAND_TEAM_GLOBAL` | Brand team, all regions. Same masking | `AR_MARTS_READ`, `AR_WH_USE` | — |
| `GLOBAL_LEADER` | Executive view: aggregated numbers by region and nation only | `AR_MARTS_AGG_READ`, `AR_WH_USE` | — |
| `RAP_ADMIN` | Deploys policies from YAML | `AR_MARTS_READ`, `AR_GOVERNANCE_APPLY`, `AR_WH_USE` | — |
| `TF_ADMIN` | Terraform | (see below) | `CREATE ROLE`, `CREATE DATABASE`, `CREATE WAREHOUSE`, grant privileges Terraform needs |

All functional roles except `TF_ADMIN` are created by Terraform and granted to `SYSADMIN`.

## Service users

| User | Default role | Created | Notes |
|------|--------------|---------|-------|
| `SVC_TERRAFORM` | `TF_ADMIN` | By hand, lesson 1.4 | Key pair; SQL committed as `bootstrap/00_terraform_user.sql` |
| `SVC_DBT` | `TRANSFORMER` | Terraform, lesson 2.6 | Key pair |
| `SVC_RAP_DEPLOYER` | `RAP_ADMIN` | Terraform, lesson 2.6 | Key pair |
| `SVC_AGENT_CALLER` | one analyst role | Terraform or by hand, lesson 2.6 | Calls the agent with `X-Snowflake-Role` set to `ANALYST_EU` or `ANALYST_US` (lesson 5.4), so it must be granted both |

## What each role reaches

This is the lesson 1.3 proof: for any role, which objects, through which grant.

| Role | `SNOWFLAKE_SAMPLE_DATA` | `ANALYTICS.STAGING` | `ANALYTICS.MARTS` | Policy objects | Warehouse |
|------|------------------------|---------------------|-------------------|----------------|-----------|
| `TRANSFORMER` | read, via `AR_SAMPLE_DATA_READ` | owns | owns | no | via `AR_WH_USE` |
| `ANALYST_EU` | no | no | read, via `AR_MARTS_READ`; rows filtered to Europe by the row access policy | no | via `AR_WH_USE` |
| `ANALYST_US` | no | no | read, via `AR_MARTS_READ`; rows filtered to America (and allowed segments) | no | via `AR_WH_USE` |
| `ANALYST_GLOBAL` | no | no | read, via `AR_MARTS_READ`; all rows | no | via `AR_WH_USE` |
| `PII_READER` | no | no | read, via `AR_MARTS_READ`; unmasked phone | no | via `AR_WH_USE` |
| `BRAND_TEAM_EU` | no | no | read, via `AR_MARTS_READ`; rows filtered to Europe; `CUSTOMER_NAME` masked | no | via `AR_WH_USE` |
| `BRAND_TEAM_US` | no | no | read, via `AR_MARTS_READ`; rows filtered to America; `CUSTOMER_NAME` masked | no | via `AR_WH_USE` |
| `BRAND_TEAM_GLOBAL` | no | no | read, via `AR_MARTS_READ`; all rows; `CUSTOMER_NAME` masked | no | via `AR_WH_USE` |
| `GLOBAL_LEADER` | no | no | `AGG_ORDERS_GEO` only, via `AR_MARTS_AGG_READ`; aggregation policy applies | no | via `AR_WH_USE` |
| `RAP_ADMIN` | no | no | read, plus apply policies | create and apply, via `AR_GOVERNANCE_APPLY` | via `AR_WH_USE` |
| `TF_ADMIN` | no | no | no | no | creates it |
| `SYSADMIN` | via its functional roles | via its functional roles | via its functional roles | via `RAP_ADMIN` | via its functional roles |

Note that `TRANSFORMER`, as owner of the marts, sees masked data by default (lesson 6.5), and the aggregation policy for it uses `NO_AGGREGATION_CONSTRAINT()` (lesson 6.8).

## Region and country access

| Role | Region | Country |
|------|--------|---------|
| `ANALYST_EU` | `EUROPE` | all |
| `ANALYST_US` | `AMERICA` | all |
| `ANALYST_GLOBAL` | all five | all |
| `BRAND_TEAM_EU` | `EUROPE` | all |
| `BRAND_TEAM_US` | `AMERICA` | all |
| `BRAND_TEAM_GLOBAL` | all five | all |
| `GLOBAL_LEADER` | all five (aggregates only) | all (aggregates only) |

Later, a country role such as `ANALYST_DE` (GERMANY only) can be added by an entitlement, without a new policy. Regions are `AFRICA`, `AMERICA`, `ASIA`, `EUROPE`, `MIDDLE EAST`.

## Brand team: customer name masking

The brand team needs to see customers' behaviour (segment, nation, orders) but not who they are. They get the same region filtering as the analysts, and a masking policy on `DIM_CUSTOMER.CUSTOMER_NAME` (for example `MASK_CUSTOMER_NAME`) returns `*** MASKED ***` unless `CURRENT_ROLE()` is on the allowlist (`ANALYST_*`, `PII_READER`). New roles are masked by default. `CUSTOMER_NAME` is not in any row access policy signature, so the two policies can coexist. The same name must also be masked wherever it is copied; today only `DIM_CUSTOMER` carries it.

## Global leader: aggregated numbers only

Two layers, because an aggregation policy only enforces a minimum group size. It does not limit which columns you can group by.

1. **Grain.** `GLOBAL_LEADER` gets no grant on the row-level tables. It can read only `AGG_ORDERS_GEO`, a dbt mart pre-grouped by `REGION_NAME` and `NATION_NAME` (order count, total price, average price, distinct customers). Nothing finer exists to query.
2. **Group size.** An aggregation policy (`MIN_GROUP_SIZE => 5`, lesson 6.8) is attached to `AGG_ORDERS_GEO`. Groups with fewer than 5 rows are dropped or collapsed into a remainder row, so a small nation cannot leak individual customers.

In TPC-H a nation is a country, so "nation" and "country" are the same level here.

## Open questions

- Does `GLOBAL_LEADER` also need `AGG_ORDERS_GEO` by segment, or strictly region and nation?

- Does `TF_ADMIN` need `MANAGE GRANTS`? It is powerful; Terraform may need it only for ownership grants (lesson 2.5). Grant the least that works and log what was needed.
- Is `TYPE = SERVICE_AGENT` settable for `SVC_AGENT_CALLER` through the provider? If not, create that one by hand (lesson 2.6).
- Should `PII_READER` be granted directly to people, or only combined with an analyst role?
- Where do policy objects live (`ANALYTICS.GOVERNANCE` or elsewhere)?
