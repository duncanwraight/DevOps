output "app_subnet_id" {
  value = aws_subnet.app.id
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.db.name
}