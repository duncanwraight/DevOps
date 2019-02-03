#!/usr/bin/env bash

# @title:   Azure VM spec inode comparison
# @purpose: Display the number of inodes each chosen spec of Azure VM offers natively
# @deps:    Accompanied by a PowerShell script which creates a load of VMs and outputs their spec
#             and IP in the required format
# @tech:    Bash
# @author:  Duncan Wraight
# @version: 0.4
# @url:     https://www.linkedin.com/in/duncanwraight

# List of VMs to access
#  Format is HOSTNAME-IP
#  Hostname doesn't need to be the actual machine's hostname, just a heading
#  Make sure no dashes exist before the -IP segment of each array entry

VMs=(
"SPEC:Standard_B1ms-IPGOESHERE"
"SPEC:Standard_B1s-IPGOESHERE"
"SPEC:Standard_B2ms-IPGOESHERE"
)

# Colour codes for text output
TXT_RED='\033[0;31m'
TXT_GRN='\033[0;32m'
TXT_BLU='\033[0;34m'
TXT_YEL='\033[1;33m'
TXT_NC='\033[0m'

SSHPrivateKey='~/.ssh/devops_test_vms'  # Path to private key which can be used to connect to all VMs
SSHUser='devopstest'                    # Username for SSH connection

# Loop through each server/IP
for i in "${VMs[@]}"
do
    # Little hack to split up the IPs and spec names rather than using an associative array
    IN=$i
    arrIN=(${IN//-/ })
    
    echo "--------"
    echo -e "${TXT_BLU}${arrIN[0]}${TXT_NC} // ${TXT_YEL}${arrIN[1]}${TXT_NC}"
    
    # Run a command, via SSH, to check the inode capacity of each server (-o removes the "yes/no" prompt for known hosts)
    sudo ssh -o "StrictHostKeyChecking no" -i ${SSHPrivateKey} ${SSHUser}@${arrIN[1]} 'df -i | sed -n "1p;/dev\/sdb/p"'
done

echo ""

