provider "snowflake" {
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = "SVC_TERRAFORM"
  role              = "TF_ADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = file(var.private_key_path)
}
