output "public_ip_address" {
  value = "${formatlist("%s: %s", azurerm_virtual_machine.vm.*.name, azurerm_public_ip.main.*.ip_address)}"
}

output "ansible" {
  value = "ansible-playbook -i inventory/mycluster/hosts.ini cluster.yml -b --private-key=${local.ssh_path} --user azureuser"
}
