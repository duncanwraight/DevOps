resource "azurerm_storage_account" "main" {
  name                      = "${local.prefix_formatted}sa"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  location                  = "${azurerm_resource_group.main.location}"
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  tags                      = "${local.tags}"
}

resource "azurerm_storage_container" "disks" {
  count                 = "${var.num_VMs}"
  name                  = "${local.prefix_formatted}${count.index}vhd"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  storage_account_name  = "${azurerm_storage_account.main.name}"
  container_access_type = "private"

  depends_on            = ["azurerm_storage_account.main"]
}
