#!/bin/bash

TXT_GRN='\033[0;32m'
NC='\033[0m'

function silentSsh {
    local connectionString="$1"
    local commands="$2"
    if [ -z "$commands" ]; then
        commands=`cat`
    fi
    ssh -T $connectionString -o StrictHostKeyChecking=no "$commands"
}

timeNow=$(date)
ip=$(ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)

echo
echo "================ MASTER NODE DATE =================="
echo -e "[Date: ${TXT_GRN}${timeNow}${NC}]"
echo "===================================================="

# Get the IP address of each node using the mesos API and store it inside a file called nodes
curl -s http://leader.mesos:1050/system/health/v1/nodes | jq '.nodes[].host_ip' | sed 's/\"//g' | sed '/172/d' > nodes # Output to file called "nodes"

# From the previous file created, run our script to mount our share on each node
cat nodes | while read line
do
silentSsh `whoami`@$line < ./datetime-check.sh
done

# Cleanup
rm nodes