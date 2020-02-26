resource "aws_instance" "app" {
	key_name               = "techops-ci"
	ami                    = "ami-xxx"
	instance_type          = "t3.medium"
	subnet_id              = var.app_subnet_id
	private_ip						 = "10.0.0.5"   # must be static to facilitate A record for hostname
	vpc_security_group_ids = [var.app_security_group_id]
	root_block_device {
		volume_size = "16"
	}
  
  tags = merge(map("Name", format("%s", "${local.name_prefix}-ec2-app")), var.default_tags)
}