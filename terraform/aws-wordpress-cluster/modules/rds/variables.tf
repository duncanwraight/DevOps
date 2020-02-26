variable "environment" {
  description = "Production, Staging, etc."
  type        = string
}

variable "db_subnet_group_name" {
  description = "Name value from DB subnet group; expected output from network module"
  type        = string
}

variable "default_tags" {
  description = "Tags to apply to all resources, excluding Name"
  type        = map
}

locals {
  name_prefix = "wp-${lower(substr(var.environment, 0, 4))}"
}