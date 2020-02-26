### Route Tables

resource "aws_route_table" "public" {
	# route table from publ subnet, targ 0.0.0.0/0, to *internet* gateway
  vpc_id = var.existing_vpc_id

  route {
    cidr_block  = "0.0.0.0/0"
    gateway_id  = var.existing_internet_gateway_id
  }

  tags = merge(map("Name", format("%s", "${local.name_prefix}-routetable-public")), var.default_tags)
}

resource "aws_route_table" "private" {
	# route table from priv subnet, targ 0.0.0.0/0, to *nat* gateway
  vpc_id = var.existing_vpc_id

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id  = aws_nat_gateway.public.id
  }

  tags = merge(map("Name", format("%s", "${local.name_prefix}-routetable-priv")), var.default_tags)
}


### Associations

resource "aws_route_table_association" "public" {
  subnet_id       = aws_subnet.public.id
  route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  subnet_id       = aws_subnet.app.id
  route_table_id  = "rtb-xxx"        # LD5 VPN Access Route Table
}

resource "aws_route_table_association" "db1" {
  subnet_id       = aws_subnet.db1.id
  route_table_id  = aws_route_table.private.id
}

resource "aws_route_table_association" "db2" {
  subnet_id       = aws_subnet.db2.id
  route_table_id  = aws_route_table.private.id
}