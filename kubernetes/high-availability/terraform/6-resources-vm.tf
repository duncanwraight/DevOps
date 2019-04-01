resource "azurerm_virtual_machine" "vm" {
  count                 = "${var.num_VMs}"
  name                  = "${local.prefix}-${count.index}-VM"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  availability_set_id   = "${azurerm_availability_set.main.id}"
  network_interface_ids = ["${azurerm_network_interface.main.*.id[count.index]}"]
  vm_size               = "Standard_B2ms"
  tags                  = "${local.tags}"

  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "osdisk"
    vhd_uri       =
"${azurerm_storage_account.main.primary_blob_endpoint}${local.prefix_formatted}${count.index}/osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_data_disk {
    name          = "datadisk1"
    vhd_uri       = "${azurerm_storage_account.main.primary_blob_endpoint}${local.prefix_formatted}${count.index}/datadisk1.vhd"
    disk_size_gb  = "1024"
    create_option = "Empty"
    lun           = 0
  }

  os_profile {
    computer_name   = "${local.prefix}-${count.index}-VM"
    admin_username  = "azureuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${tls_private_key.privkey.public_key_openssh}"
    } 
  }

  depends_on = ["azurerm_storage_container.disks"]
}
