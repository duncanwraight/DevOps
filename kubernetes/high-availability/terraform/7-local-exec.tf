locals {
  vm_pips = "${join(" ", azurerm_public_ip.main.*.ip_address)}"
  root_path = "my/device/path/kubernetes/high-availability"
  kubespray_path = "${local.root_path}/kubespray-2.8.3"
  cluster_inventory_path = "${local.kubespray_path}/inventory/mycluster"
  ssh_path = "~/.ssh/k8s_ha_test"
}

resource "null_resource" "null_id" {
  triggers {
    vm_ids = "${join(",", azurerm_virtual_machine.vm.*.id)}"
  }

  provisioner "local-exec" {
    working_dir = "${local.root_path}"
    command = "bash ssh-keyscan-ips.sh ${local.vm_pips}"
  }

  provisioner "local-exec" {
    command = "rm -rfd '${local.cluster_inventory_path}'" 
  }

  provisioner "local-exec" {
    command = "cp -R '${local.kubespray_path}/inventory/sample' '${local.cluster_inventory_path}'"
  }

  provisioner "local-exec" {
    working_dir = "${local.kubespray_path}"
    command = "CONFIG_FILE=inventory/mycluster/hosts.ini python3 contrib/inventory_builder/inventory.py ${local.vm_pips}"
  }

  provisioner "local-exec" {
    command = "echo '${tls_private_key.privkey.private_key_pem}' > ${local.ssh_path}"
  }

  provisioner "local-exec" {
    command = "chmod 600 ${local.ssh_path}"
  }
}
