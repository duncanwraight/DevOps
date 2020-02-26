# publ subnet (10.0.0.0/24)
resource "aws_subnet" "public" {
  vpc_id              = var.existing_vpc_id
  cidr_block          = "10.0.0.0/24"

  tags                = merge(map("Name", format("%s", "${local.name_prefix}-subnet-publ")), var.default_tags)
}

# app subnet (10.0.1.0/24)
resource "aws_subnet" "app" {
  vpc_id              = var.existing_vpc_id
  cidr_block          = "10.0.1.0/24"
  availability_zone   = "eu-west-1b"

  tags                = merge(map("Name", format("%s", "${local.name_prefix}-subnet-app")), var.default_tags)
}

# db1 subnet (10.0.2.0/24)
#  must be diff az to db2
resource "aws_subnet" "db1" {
  vpc_id              = var.existing_vpc_id
  cidr_block          = "10.0.2.0/24"
  availability_zone   = "eu-west-1a"

  tags                = merge(map("Name", format("%s", "${local.name_prefix}-subnet-db1")), var.default_tags)
}

# db2 subnet (10.0.3.0/24)
#  must be diff az to db1
resource "aws_subnet" "db2" {
  vpc_id              = var.existing_vpc_id
  cidr_block          = "10.0.3.0/24"
  availability_zone   = "eu-west-1c"

  tags                = merge(map("Name", format("%s", "${local.name_prefix}-subnet-db2")), var.default_tags)
}