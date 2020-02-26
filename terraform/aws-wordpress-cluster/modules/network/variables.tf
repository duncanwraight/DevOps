variable "existing_vpc_id" {
  description = "The ID of the VPC which our VPN currently transits to"
  type        = string
}

variable "existing_internet_gateway_id" {
  description = "The ID of the Internet Gateway attached to the Existing VPC"
  type        = string
}

variable "environment" {
  description = "Production, Staging, etc."
  type        = string
}

variable "default_tags" {
  description = "Tags to apply to all resources, excluding Name"
  type        = map
}

locals {
  name_prefix = "wp-${lower(substr(var.environment, 0, 4))}"
}