resource "azurerm_resource_group" "main" {
  name      = "${local.prefix}-RG"  
  location  = "ukwest"
  tags      = "${local.tags}"
}

resource "azurerm_availability_set" "main" {
  name                = "${local.prefix}-ASET"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}
