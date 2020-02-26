### Elastic IPs

resource "aws_eip" "nat" {
  vpc = true
}


### NAT Gateways
  # (allowing resources in private subnets to access the internet)
resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags          = merge(map("Name", format("%s", "${local.name_prefix}-natgateway-publ")), var.default_tags)
}


### Security Groups

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-securitygroup-app"
  description = "Web/SSH ingress from LD5 VPN servers and unrestricted outbound access"
  vpc_id      = var.existing_vpc_id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


### RDS Subnet Groups

resource "aws_db_subnet_group" "db" {
  name        = "${local.name_prefix}-subnetgroup"
  subnet_ids  = [aws_subnet.db1.id, aws_subnet.db2.id]

  tags        = merge(map("Name", format("%s", "${local.name_prefix}-subnetgroup")), var.default_tags)
}