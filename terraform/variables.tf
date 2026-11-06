variable "organization_name" {
  type        = string
  description = "Snowflake organization name (the part of the account identifier before the hyphen)"
}

variable "account_name" {
  type        = string
  description = "Snowflake account name (the part after the hyphen)"
}

variable "private_key_path" {
  type        = string
  description = "Path to the SVC_TERRAFORM private key (.p8). Never commit the key."
  sensitive   = true
}
