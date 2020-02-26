########################################
# main.tf
########################################

provider "aws" {
  region                         = "eu-west-1"
  shared_credentials_file        = "/users/test/.aws/credentials"
  profile                        = "default"
}

########################################

locals {
  default_tags = {
    Project           = "Single AZ WordPress cluster"
    Expiry_Date       = "Never"
    Environment_Name  = "Staging"
    Resource_Owner    = "Duncan Wraight"
  }
}

module "network" {
  source = "../../modules/network"

  # Use existing VPC/IGW due to VPN link
  existing_vpc_id               = "vpc-xxx"
  existing_internet_gateway_id  = "igw-xxx"
  environment                   = "Staging"
  default_tags                  = local.default_tags
}

module "ec2" {
  source = "../../modules/ec2"

  environment           = "Staging"
  app_subnet_id         = module.network.app_subnet_id
  app_security_group_id = module.network.app_security_group_id
  default_tags          = local.default_tags
}

module "rds" {
  source = "../../modules/rds"

  environment           = "Staging"
  db_subnet_group_name  = module.network.db_subnet_group_name
  default_tags          = local.default_tags
}