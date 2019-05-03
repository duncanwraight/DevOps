output "01-public_ip_addresses" {
  value = "${formatlist("%s: %s", azurerm_virtual_machine.vm.*.name, azurerm_public_ip.main.*.ip_address)}"
}

output "02-linespace" {
  value = "---"
}

output "03-ansible" {
  value = "ansible-playbook -i ../kubespray-2.8.3/inventory/mycluster/hosts.yml ../kubespray-2.8.3/cluster.yml -b --private-key=${local.ssh_path} --user azureuser"
}