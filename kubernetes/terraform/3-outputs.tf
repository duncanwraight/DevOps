output "public_ip_address" {
  value = "${formatlist("%s: %s", azurerm_virtual_machine.vm.*.name, azurerm_public_ip.main.*.ip_address)}"
}
