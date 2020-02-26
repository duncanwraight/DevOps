variable "environment" {
  description = "Production, Staging, etc."
  type        = string
}

variable "default_tags" {
  description = "Tags to apply to all resources, excluding Name"
  type        = map
}

variable "app_subnet_id" {
  description = "Subnet ID for the APP subnet; an expected output from the network module"
  type        = string
}

variable "app_security_group_id" {
  description = "Security Group ID for the APP security group; an expected output from the network module"
  type        = string
}

locals {
  name_prefix = "wp-${lower(substr(var.environment, 0, 4))}"
}