# @title:   VM cluster creation script
# @file:    Outputs (e.g. what Terraform will display when job is complete)
# @tech:    Terraform
# @author:  Duncan Wraight
# @version: 0.4
# @url:     https://www.linkedin.com/in/duncanwraight

output "public_ip_address" {
  value = ["${azurerm_public_ip.main.*.ip_address}"]
}
