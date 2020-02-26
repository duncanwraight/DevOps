# @title:   VM cluster creation script
# @file:    Resource creation
# @tech:    Terraform
# @author:  Duncan Wraight
# @version: 0.4
# @url:     https://www.linkedin.com/in/duncanwraight

resource "azurerm_resource_group" "main" {
  name      = "${local.prefix_group}-RG"  
  location  = "ukwest"
  tags      = "${local.tags}"
}

resource "azurerm_virtual_network" "main" {
  name                = "${local.prefix_group}-VNET" 
  address_space       = ["10.0.0.0/22"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  tags                = "${local.tags}"
}

resource "azurerm_subnet" "internal" {
  name                  = "internal"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  virtual_network_name  = "${azurerm_virtual_network.main.name}"
  address_prefix        = "10.0.0.0/22"
}

resource "azurerm_public_ip" "main" {
  count               = "${local.count_of_types}"
  name                = "${replace(local.prefix_specific,"##TYPE##",var.type[count.index])}-PIP"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "main" {
  count               = "${local.count_of_types}"
  name                = "${replace(local.prefix_specific,"##TYPE##",var.type[count.index])}-NIC" 
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  tags                = "${local.tags}"

  ip_configuration {
    name                          = "${replace(local.prefix_lower,"##type##",lower(var.type[count.index]))}ip"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.main.*.id[count.index]}"
  }
}

resource "azurerm_storage_account" "main" {
  name                      = "${local.name_sacc}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  location                  = "${azurerm_resource_group.main.location}"
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  tags                      = "${local.tags}"
}

resource "azurerm_storage_container" "disks" {
  count                 = "${local.count_of_types}"
  name                  = "${replace(local.prefix_lower,"##type##",lower(var.type[count.index]))}vhd"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  storage_account_name  = "${azurerm_storage_account.main.name}"
  container_access_type = "private"

  depends_on            = ["azurerm_storage_account.main"]
}

resource "azurerm_virtual_machine" "vm" {
  count                 = "${local.count_of_types}"
  name                  = "${replace(local.prefix_specific,"##TYPE##",var.type[count.index])}-VM"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
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
    vhd_uri       = "${azurerm_storage_account.main.primary_blob_endpoint}${replace(local.prefix_lower,"##type##",lower(var.type[count.index]))}/osdisk.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  storage_data_disk {
    name          = "datadisk1"
    vhd_uri       = "${azurerm_storage_account.main.primary_blob_endpoint}${replace(local.prefix_lower,"##type##",lower(var.type[count.index]))}/datadisk1.vhd"
    disk_size_gb  = "1024"
    create_option = "Empty"
    lun           = 0
  }

  os_profile {
    computer_name   = "${replace(local.prefix_specific,"##TYPE##",var.type[count.index])}-VM"
    admin_username  = "azureuser"
    admin_password  = "CHANGETHISPASSWORD123!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  depends_on = ["azurerm_storage_container.disks"]
}
