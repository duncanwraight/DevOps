#!/bin/bash

# Install jq used for the next command
#sudo apt-get install jq -y

# Get the IP address of each node using the mesos API and store it inside a file called nodes
curl http://leader.mesos:1050/system/health/v1/nodes | jq '.nodes[].host_ip' | sed 's/\"//g' | sed '/172/d'
curl http://leader.mesos:1050/system/health/v1/nodes | jq '.nodes[].host_ip' | sed 's/\"//g' | sed '/172/d' > nodes

# From the previous file created, run our script to mount our share on each node
cat nodes | while read line
do
  echo "ssh ${whoami}@${line} -o StrictHostKeyChecking=no < ./docker-prune.sh" 
  ssh `whoami`@$line -o StrictHostKeyChecking=no < ./docker-prune.sh 
done

# Cleanup
rm nodes

echo ""
echo -e "Script ran succesfully....exiting"
