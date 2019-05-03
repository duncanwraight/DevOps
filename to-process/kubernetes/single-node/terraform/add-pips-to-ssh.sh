ANS_INVENTORY="../ansible/ans-inventory.yml"

IP_MASTER=$1
IP_SLAVE=$2

ALL_VARS="[all:vars]
ansible_user=azureuser
ansible_ssh_pass=Password1!"

CLUSTER="[cluster:children]
master
slave"

MASTER="[master]
${IP_MASTER}"

SLAVE="[slave]
${IP_SLAVE}"

ssh-keyscan -H "${IP_MASTER}" >> ~/.ssh/known_hosts
ssh-keyscan -H "${IP_SLAVE}" >> ~/.ssh/known_hosts

rm "${ANS_INVENTORY}"

echo "${ALL_VARS}

${CLUSTER}

${MASTER}

${SLAVE}" > "${ANS_INVENTORY}"
