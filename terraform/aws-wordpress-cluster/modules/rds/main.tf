resource "aws_db_instance" "db" {
  identifier                = "${local.name_prefix}-rds"
  allocated_storage         = 20 #min
  storage_type              = "gp2"
  engine                    = "mariadb"
  engine_version            = "10.3.13"
  instance_class            = "db.t2.micro"
  db_subnet_group_name      = var.db_subnet_group_name
  name                      = "wordpress"
  username                  = "admin"
  password                  = "Password12345!"
  final_snapshot_identifier = "${local.name_prefix}-rds-termination-backup"
  skip_final_snapshot       = true

  tags = merge(map("Name", format("%s", "${local.name_prefix}-subnet-db1")), var.default_tags)
}