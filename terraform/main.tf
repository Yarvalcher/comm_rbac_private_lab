resource "snowflake_warehouse" "lab" {
  name                = "LAB_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = "true"
  initially_suspended = true
}

resource "snowflake_database" "analytics" {
  name = "ANALYTICS"
}
