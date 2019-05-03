#!/bin/bash

# Server variables
NodeIPs=( "$@" )  # Get a list of IP addresses from the command line
SSHPrivateKey="~/.ssh/k8s_ha_test"
Username="azureuser"

# Folder paths
KubesprayPath="kubespray-2.8.3"
InventoryPath="${KubesprayPath}/inventory/mycluster"

# Run another shell script to add all of the Node IP addresses to our machine's SSH Known Hosts
bash ssh-keyscan-ips.sh $NodeIPs

# Copy a "template" folder of Ansible variables used by Kubespray
rm -rfd $InventoryPath
cp -R $KubesprayPath/inventory/sample $InventoryPath
rm $InventoryPath/hosts.ini

# Use a contributed builder script to create a valid Ansible Inventory with the node IP addresses
CONFIG_FILE=inventory/mycluster/hosts.yml python3 contrib/inventory_builder/inventory.py $NodeIPs

# Run the Kubespray Ansible Playbook which starts the deployment of the cluster
ansible-playbook -i $InventoryPath/hosts.yml $InventoryPath/cluster.yml -b --private-key=$SSHPrivateKey --user $Username
