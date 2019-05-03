resource "azurerm_virtual_network" "main" {
  name                = "${local.prefix}-VNET" 
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
  count               = "${var.num_VMs}"
  name                = "${local.prefix}-${count.index}-VM-PIP"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "lb" {
  name                = "${local.prefix}-LB-PIP"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  allocation_method   = "Static"
}

resource "azurerm_lb" "main" {
  name                = "${local.prefix}-LB"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  
  frontend_ip_configuration {
    name                  = "${local.prefix_formatted}pipfec"
    public_ip_address_id  = "${azurerm_public_ip.lb.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  name                = "${local.prefix_formatted}pool"
  resource_group_name = "${azurerm_resource_group.main.name}"
  loadbalancer_id     = "${azurerm_lb.main.id}"
}

resource "azurerm_network_interface" "main" {
  count               = "${var.num_VMs}"
  name                = "${local.prefix}-${count.index}-NIC" 
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  tags                = "${local.tags}"

  ip_configuration {
    name                          = "${local.prefix_formatted}${count.index}ip"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.main.*.id[count.index]}"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = "${var.num_VMs}"
  network_interface_id    = "${azurerm_network_interface.main.*.id[count.index]}"
  ip_configuration_name   = "${local.prefix_formatted}${count.index}ip"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.main.id}"
}
