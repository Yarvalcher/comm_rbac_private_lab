# comm_rbac_private_lab

Personal learning project, built on Snowflake sample data only. Not affiliated with any employer.

## Branches

| Branch | Purpose |
|--------|---------|
| `dev` | Day-to-day work. Changes are deployed here first. |
| `uat` | Testing before release. Updated only by a pull request from `dev`. |
| `prod` | Production, the default branch (renamed from `main`). Updated only by a pull request from `uat`. |

Flow: `dev` → `uat` → `prod`. Nothing reaches `uat` or `prod` except through a pull request.
