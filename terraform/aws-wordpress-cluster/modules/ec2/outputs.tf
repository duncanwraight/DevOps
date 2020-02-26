output "app_ec2_priv_ip" {
  value = aws_instance.app.private_ip
}